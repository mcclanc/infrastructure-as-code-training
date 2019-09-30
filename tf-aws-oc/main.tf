## AWS Tag configuration

variable "aws_tag_owner" {
  description = "Instance owner"
  default = "root"
}

variable "aws_tag_environment" {
  description = "Whether instance is production, test, development, etc"
  default = "Development"
}

variable "aws_tag_billing" {
  description = "Billing information for instance"
  default = "n/a"
}

variable "aws_tag_application" {
  description = "Application tag"
  default = "opencart"
}

variable "aws_tag_customer" {
  description = "Customer"
  default = "n/a"
}

## AWS configuration

variable "aws_keyname" {
  description = "Name of the SSH keypair to use in AWS"
  default = "key-opencart"
}

variable "aws_region" {
  description = "AWS region to launch servers"
  default = "us-west-1"
}

variable "aws_availability_zones" {
  description = "AWS region to launch servers"
  default = "us-west-1a,us-west-1c"
}

variable "aws_sgname" {
  description = "Name of security group to use in AWS"
  default = "app-opencart"
}

variable "internal_cidr_blocks"{
  default = "0.0.0.0/0"
}


provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_security_group" "opencart" {
  name = "${var.aws_sgname}"
  description = "World web access with ssh"
  #vpc_id = "${var.aws_vpc_id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${split(",", var.internal_cidr_blocks)}"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["${split(",", var.internal_cidr_blocks)}"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["${split(",", var.internal_cidr_blocks)}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

## App configuration

variable "oc_db_host" {
  default = "localhost"
}
variable "oc_db_user" {
  default = "admin"
}
variable "oc_db_pass" {
  default = "mysql"
}
variable "oc_db_type" {
  default = "mysql"
}
variable "oc_db_db" {
  default = "opencart"
}
variable "oc_user" {
  default = "admin"
}
variable "oc_pass" {}
variable "oc_email" {
  default = "root@localhost"
}
variable "oc_www_host" {}
variable "oc_www_path" {
  default = "/store"
}
variable "mysql_password" {
  default = ""
}

resource "template_file" "user_data" {
  template = "${file("${path.module}/templates/user-data.tpl.sh")}"

  vars {
    oc_www_path             = "${var.oc_www_path}"
    oc_www_host             = "${var.oc_www_host}"
    oc_db_host              = "${var.oc_db_host}"
    oc_db_user              = "${var.oc_db_user}"
    oc_db_pass              = "${var.oc_db_pass}"
    oc_db_type              = "${var.oc_db_type}"
    oc_db_db                = "${var.oc_db_db}"
    oc_user                 = "${var.oc_user}"
    oc_pass                 = "${var.oc_pass}"
    oc_email                = "${var.oc_email}"
    mysql_password          = "${var.mysql_password}"
    aws_sg                  = "${aws_security_group.opencart.id}"
    aws_region              = "${var.aws_region}"
    aws_availability_zones  = "${var.aws_availability_zones}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

## Instance configuration

variable "aws_instance_ami" {
  description = "AMI ID for instances"
  default = "ami-0e087a6e"
}

variable "aws_instance_type" {
  description = "Instance type"
  default = "t1.micro"
}

variable "aws_instance_spot_max_bid" {
  default = "0.006"
}

# if you have multiple clusters sharing the same es_environment..?
variable "oc_cluster" {
  description = "Opencart cluster name"
}

# the ability to add additional existing security groups. In our case
# we have consul running as agents on the box
variable "additional_security_groups" {
  default = ""
}

resource "aws_spot_instance_request" "opencart" {
  ami = "${var.aws_instance_ami}"
  spot_price = "${var.aws_instance_spot_max_bid}"
  instance_type = "${var.aws_instance_type}"
  vpc_security_group_ids = ["${aws_security_group.opencart.id}"]
  key_name = "${var.aws_keyname}"
  user_data = "${template_file.user_data.rendered}"
  wait_for_fulfillment = true

  tags {
    Name = "sir-${var.oc_cluster}-tf-oc"
    Owner = "${var.aws_tag_owner}"
    Application = "${var.aws_tag_application}"
    Billing = "${var.aws_tag_billing}"
    Environment = "${var.aws_tag_environment}"
    Customer = "${var.aws_tag_customer}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "opencart" {
  name = "elb-${var.oc_cluster}-tf-oc"
  availability_zones = ["${split(",", var.aws_availability_zones)}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval = 30
  }

  instances = ["${aws_spot_instance_request.opencart.spot_instance_id}"]
  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400

  tags {
    Name = "elb-${var.oc_cluster}-tf-oc"
  }
}

# AWS Route53 configuration

variable "aws_route53_zoneid" {
}

variable "aws_route53_a_name" {
}

resource "aws_route53_record" "www" {
  zone_id = "${var.aws_route53_zoneid}"
  name = "${var.aws_route53_a_name}"
  type = "A"

  alias {
    name = "${aws_elb.opencart.dns_name}"
    zone_id = "${aws_elb.opencart.zone_id}"
    evaluate_target_health = true
  }
}

## Output

output "aws_spot_instance_request.opencart.public_dns" {
  value = "${aws_spot_instance_request.opencart.public_ip}"
}
