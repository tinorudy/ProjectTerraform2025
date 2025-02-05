provider "aws" {
  profile = "default"
  region = "eu-west-2"
}

provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}

resource "aws_s3_bucket" "www" {
  bucket = "www.fiffik.co.uk"
  force_destroy = "true"
}

resource "aws_s3_bucket_ownership_controls" "demoacl" {
  bucket = aws_s3_bucket.www.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "demoacl" {
  bucket = aws_s3_bucket.www.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "acl_newest" {
  depends_on = [
    aws_s3_bucket_ownership_controls.demoacl,
    aws_s3_bucket_public_access_block.demoacl,
  ]

  bucket = aws_s3_bucket.www.id
  acl    = "public-read"
}




resource "aws_s3_bucket_policy" "s3_bucket" {
  bucket = aws_s3_bucket.www.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          aws_s3_bucket.www.arn,
          "${aws_s3_bucket.www.arn}/*",
        ]
      },
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "staticweb" {
  bucket = aws_s3_bucket.www.id

  index_document {
    suffix = "index.html"

  }

}

resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.www.id
  key    = "index.html"
  source = "~/index.html"
  content_type = "html"
  etag = filemd5("~/index.html")
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.acm_provider
  domain_name       = "fiffik.co.uk"
  subject_alternative_names = ["*.fiffik.co.uk"]
  validation_method = "DNS"


  lifecycle {
    create_before_destroy = true
  }

}

data "aws_route53_zone" "tino" {
  name         = "fiffik.co.uk"
  private_zone = false
}

resource "aws_route53_record" "tinorudy" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.tino.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  provider        = aws.acm_provider
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.tinorudy : record.fqdn]
}

resource "aws_cloudfront_distribution" "www_s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.www.website_endpoint
    origin_id   = "S3-www.fiffik.co.uk"
  

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["*.fiffik.co.uk"]

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 404
    response_code         = 200
    response_page_path    = "/404.html"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-www.fiffik.co.uk"
    
    

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 31536000
    default_ttl            = 31536000
    max_ttl                = 31536000
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.main.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

  
}

#resource "aws_route53_record" "a" {
#  zone_id = data.aws_route53_zone.tino.zone_id
#  name    = "maintenance.fiffik.co.uk"
#  type    = "A"

#  alias {
#    name                   = aws_cloudfront_distribution.www_s3_distribution.domain_name
#    zone_id                = aws_cloudfront_distribution.www_s3_distribution.hosted_zone_id
#    evaluate_target_health = false
#  }
#}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.tino.zone_id
  name    = "www.fiffik.co.uk"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.www_s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.www_s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }

  failover_routing_policy {
    type = "SECONDARY"
    
  }
  #health_check_id = aws_route53_health_check.demo-healthcheck.id
  set_identifier = "www"

}