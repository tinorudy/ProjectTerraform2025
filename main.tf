provider "aws" {
  profile = "default"
  region  = "eu-west-2"
}



resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/24"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "demo-training-vpc"
  }
}

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/28"
  availability_zone = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "demo-training-public-subnet-1"
  }

}

resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.16/28"
  availability_zone = "eu-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "demo-training-public-subnet-2"
  }

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "demo-training-igw"
  }
}

resource "aws_route_table" "rtb1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name  = "demo-training-rtb-1"
  }
}

resource "aws_route_table" "rtb2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name  = "demo-training-rtb-2"
  }
}

resource "aws_route_table_association" "main1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.rtb1.id
}

resource "aws_route_table_association" "main2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.rtb2.id
}

resource "aws_security_group" "sg" {
  name        = "demo-training-sg"
  description = "Allow inbound traffic access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["94.4.240.161/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "demo-training-sg"
  }
  
}

resource "aws_instance" "public-instance" {
  instance_type = "t2.micro"
  ami = "ami-091f18e98bc129c4e"
  key_name = "tino2025"
  vpc_security_group_ids = [ aws_security_group.sg.id ]
  subnet_id = aws_subnet.public1.id
  associate_public_ip_address = true
  user_data = file("${path.module}/bootstrap.sh")

  tags = {
    Name = "demo-training-public-server-1"
  }
}

resource "aws_instance" "public-instance1" {
  instance_type = "t2.micro"
  ami = "ami-091f18e98bc129c4e"
  key_name = "tino2025"
  vpc_security_group_ids = [ aws_security_group.sg.id ]
  subnet_id = aws_subnet.public2.id
  associate_public_ip_address = true
  user_data = file("${path.module}/bootstrap.sh")

  tags = {
    Name = "demo-training-public-server-2"
  }
}

resource "aws_lb" "main" {
  name = "demo-training-alb"
  internal = false 
  load_balancer_type = "application"
  security_groups = [ aws_security_group.sg.id ]
  subnets = [aws_subnet.public1.id,aws_subnet.public2.id]
  enable_deletion_protection = false

}

resource "aws_lb_target_group" "tg" {
  name = "demo-training-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  
}

resource "aws_lb_target_group_attachment" "tg-attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.public-instance.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg-attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.public-instance1.id
  port             = 80
}

resource "aws_lb_listener" "application" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "*.fiffik.co.uk"
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
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.tinorudy : record.fqdn]
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.tino.zone_id
  name    = "www"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}