variable "aws_access_key" {
  default = "*****************"
}

variable "aws_secret_key" {
 default = "******************************"
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
  default = "ubuntu"
}

data "aws_availability_zones" "available" {}


