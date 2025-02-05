provider "aws" {
  profile = var.profile.0
  region  = var.region.1
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

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  count = length(var.public_cidr)
  cidr_block = element(var.public_cidr,count.index)
  availability_zone = element(var.public_az,count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = element(var.public_subnet_name,count.index)
  }

}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  count = length(var.private_cidr)
  cidr_block = element(var.private_cidr,count.index)
  availability_zone = element(var.private_az,count.index)
  

  tags = {
    Name = element(var.private_subnet_name,count.index)
  }

}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "demo-training-igw"
  }
}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.main.id
  count = var.rtb_amt

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name  = element(var.rtb_name,count.index)
  }
}

resource "aws_route_table_association" "main" {
  count = length(var.public_cidr)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = element(aws_route_table.rtb.*.id, count.index)
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
    Name = "demo-training-public-sg"
  }
  
}


resource "aws_instance" "public" {
  instance_type = "t2.micro"
  ami = "ami-091f18e98bc129c4e"
  count = length(var.public_cidr)
  key_name = var.key_name
  vpc_security_group_ids = [ aws_security_group.sg.id ]
  subnet_id = element(aws_subnet.public.*.id,count.index)
  associate_public_ip_address = true
  
  

  tags = {
    Name = element(var.public_instance_name,count.index)
  }
}

resource "aws_instance" "private" {
  instance_type = "t2.micro"
  ami = "ami-091f18e98bc129c4e"
  count = length(var.private_cidr)
  key_name = var.key_name
  vpc_security_group_ids = [ aws_security_group.sg.id ]
  subnet_id = element(aws_subnet.private.*.id,count.index)
  
  
  

  tags = {
    Name = element(var.private_instance_name,count.index)
  }
}

resource "aws_lb" "main" {
  name = "demo-training-alb"
  internal = false 
  load_balancer_type = "application"
  security_groups = [ aws_security_group.sg.id ]
  subnets = aws_subnet.public.*.id
  enable_deletion_protection = false

}