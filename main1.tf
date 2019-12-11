#----provider----

provider "aws" {
  version = "~> 2.7"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region  = "us-east-1"
}

#---Key----

resource "aws_key_pair" "mykey" {
  key_name = "mykey"
  public_key = "${file("${var.PATH_TO_PUBLIC_KEY}")}"
}


#---Security groups----

#public security group

resource "aws_security_group" "wp_sg" {
  name        = "wp_sg"
  description = "used for elastic load balancer for public"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #HTTP

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#----VPC----

resource "aws_vpc" "wp_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wp_vpc"
  }
}

#intergateway

resource "aws_internet_gateway" "wp_internet_gateway" {
  vpc_id = "${aws_vpc.wp_vpc.id}"

  tags = {
    Name = "wp_igw"
  }
        }

#Route tables

resource "aws_route_table" "wp_public_rt" {
  vpc_id = "${aws_vpc.wp_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.wp_internet_gateway.id}"
  }

  tags = {
    Name = "wp_public"
  }
}

resource "aws_default_route_table" "wp_private_rt" {
  default_route_table_id = "${aws_vpc.wp_vpc.default_route_table_id}"



  tags = {
    Name = "wp_private"
  }
}

#subnets

resource "aws_subnet" "wp_public1_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags = {
    Name = "wp_public1"
  }
}

resource "aws_subnet" "wp_public2_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags = {
    Name = "wp_public2"
  }
}

resource "aws_subnet" "wp_private1_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags = {
    Name = "wp_private1"
  }
}

resource "aws_subnet" "wp_private2_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags = {
    Name = "wp_private2"
  }
}

#public subnet group

# subnet associations

resource "aws_route_table_association" "wp_public1_assoc" {
  subnet_id      = "${aws_subnet.wp_public1_subnet.id}"
  route_table_id = "${aws_route_table.wp_public_rt.id}"
}

resource "aws_route_table_association" "wp_public2_assoc" {
  subnet_id      = "${aws_subnet.wp_public2_subnet.id}"
  route_table_id = "${aws_route_table.wp_public_rt.id}"
}

#private associations

resource "aws_route_table_association" "wp_private1_assoc" {
  subnet_id      = "${aws_subnet.wp_private1_subnet.id}"
  route_table_id = "${aws_default_route_table.wp_private_rt.id}"
}

resource "aws_route_table_association" "wp_private2_assoc" {
  subnet_id      = "${aws_subnet.wp_private2_subnet.id}"
  route_table_id = "${aws_default_route_table.wp_private_rt.id}"
}

#NAT gateway

# NAT
resource "aws_eip" "neweip" {
  vpc   = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.neweip.id}"
  subnet_id     = "${aws_subnet.wp_public1_subnet.id}"
}

resource "aws_route" "nat_gateway" {
  route_table_id         = "${aws_default_route_table.wp_private_rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.nat.id}"

}



#----ELB---

resource "aws_iam_server_certificate" "test_cert" {
  name             = "some_test_cert"
  certificate_body = "${file("server.csr")}"
  private_key      = "${file("server.key")}"
}

resource "aws_elb" "wp_elb" {
  name = "newbalancer-elb"

  subnets = ["${aws_subnet.wp_public1_subnet.id}",
    "${aws_subnet.wp_public2_subnet.id}",
  ]

  security_groups = ["${aws_security_group.wp_sg.id}"]

  listener {
    instance_port     = 8080
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }
 listener {
    instance_port     = 8443
    instance_protocol = "https"
    lb_port           = 443
    lb_protocol       = "https"
    ssl_certificate_id = "${aws_iam_server_certificate.test_cert.arn}"
  }



  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

 cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "wp_elb_new"
  }
}

#launch configuration

resource "aws_launch_configuration" "wp_lc" {
  name_prefix   = "wp_lc-"
  image_id      = "${aws_ami_from_instance.wp_golden.id}"
  instance_type = "t2.micro"

  security_groups = ["${aws_security_group.wp_sg.id}"]

  key_name                    = "${aws_key_pair.mykey.key_name}"

  lifecycle {
    create_before_destroy = true
  }
}

#autoscaling

resource "aws_autoscaling_group" "wp_asg" {
  name = "prod"
  launch_configuration = "${aws_launch_configuration.wp_lc.name}"
  vpc_zone_identifier = ["${aws_subnet.wp_private1_subnet.id}",
    "${aws_subnet.wp_private2_subnet.id}",
  ]
  min_size          = 2
  max_size          = 4
  load_balancers    = ["${aws_elb.wp_elb.id}"]
  health_check_type = "EC2"

tags = [
{
    key                 = "Name"
    value               = "prod"
    propagate_at_launch = true
  },

{
    key                 = "Name1"
    value               = "prod1"
    propagate_at_launch = true

}
]
}
resource "aws_autoscaling_policy" "cpu_policy" {
  name                   = "CpuPolicy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.wp_asg.name}"
}

resource "aws_cloudwatch_metric_alarm" "monitor_cpu" {
  namespace           = "CPUwatch"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"

  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.wp_asg.name}"
  }

  alarm_name    = "cpuwatch-asg"
  alarm_actions = ["${aws_autoscaling_policy.cpu_policy.arn}"]
}

resource "aws_autoscaling_policy" "policy_down" {
  name                   = "downPolicy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.wp_asg.name}"
}


resource "aws_cloudwatch_metric_alarm" "monitor_down" {
  namespace           = "downwatch"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"

  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.wp_asg.name}"
  }

  alarm_name    = "downwatch-asg"
  alarm_actions = ["${aws_autoscaling_policy.cpu_policy.arn}"]
}

#---AMI--

resource "aws_ami_from_instance" "wp_golden" {
  name               = "wp_ami_httpd"
  source_instance_id = "${aws_instance.webserver.id}"
}

#instances

resource "aws_instance" "webserver" {
  ami             =  "${lookup(var.AMIS, var.AWS_REGION)}"
  instance_type   = "t2.micro"
  key_name        = "${aws_key_pair.mykey.key_name}"
  vpc_security_group_ids = ["${aws_security_group.wp_sg.id}"]
  subnet_id       = "${aws_subnet.wp_public1_subnet.id}"

provisioner "remote-exec" {
script = "wait_for_instance.sh"
}



provisioner "local-exec" {
     command = "echo \"[httpd-servers]\n${aws_instance.webserver.public_ip} ansible_connection=ssh ansible_ssh_user=ec2-user ansible_ssh_private_key_file=mykey host_key_checking=False\" > httpd-inventory &&  ansible-playbook -i httpd-inventory ansible-playbooks/httpd.yml "
}
 connection {
    user = "${var.INSTANCE_USERNAME}"
    private_key = "${file("${var.PATH_TO_PRIVATE_KEY}")}"
    host = self.public_ip 
}


 tags = {
     Name = "Hello"
   }
}

