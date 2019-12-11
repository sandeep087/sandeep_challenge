variable "aws_access_key" {
  default = "AKIAQ45XJYJY76YCNWKM"
}

variable "aws_secret_key" {
 default = "wUcdn57kP6pTQbOlB0ETqh5/0iY3NkTmWBWJiK9o"
}

variable "AWS_REGION" {
  default = "us-east-1"
}
variable "AMIS" {
  type = "map"
  default = {
    us-east-1 = "ami-0bba96c31d87e65d9"
  }
}

variable "PATH_TO_PRIVATE_KEY" {
  default = "mykey"
}
variable "PATH_TO_PUBLIC_KEY" {
  default = "mykey.pub"
}
variable "INSTANCE_USERNAME" {
  default = "ec2-user"
}

data "aws_availability_zones" "available" {}


