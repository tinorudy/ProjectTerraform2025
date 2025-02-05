
variable "profile" {
  type = list(string)
}

variable "region" {
  type = list(string)
}

variable "public_cidr" {
    type = list(string)
  
}

variable "private_cidr" {
    type = list(string)
  
}
variable "london_az" {
  type = list(string)
}

variable "ireland_az" {
  type = list(string)
}
variable "public_az" {
  type = list(string)
}

variable "private_az" {
  type = list(string)
}
variable "public_subnet_name" {
  type = list(string)
}

variable "private_subnet_name" {
  type = list(string)
}


variable "rtb_amt" {
   type = number
}

variable "rtb_name" {
  type = list(string)
}
variable "key_name" {
  type = string
}
variable "public_instance_name" {
  type = list(string)
}

variable "private_instance_name" {
  type = list(string)
}

