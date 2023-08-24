packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.9"
      source = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.0.1"
      source = "github.com/hashicorp/ansible"
    }
  }
}

variable "ami_name" {
  type    = string
  default = "batch-gpu-mpi"
}

variable "ami_version" {
  type    = string
  default = "1.0.0"
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "instance_type" {
  type    = string
  default = "p3.2xlarge"
}

variable "inventory_directory" {
  type    = string
  default = "inventory"
}

variable "playbook_file" {
  type    = string
  default = "packer-playbook.yml"
}

variable "ssh_username" {
  type    = string
  default = "ec2-user"
}

variable "docker_cache" {
  type    = string
  default = ""
}

variable "docker_username" {
  type    = string
  default = "AWS"
}

variable "docker_password" {
  type    = string
  default = ""
}

# "timestamp" template function replacement
locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "aws-batch-ami" {
  ami_name      = "${var.ami_name}-${var.ami_version}-${local.timestamp}"
  instance_type = "${var.instance_type}"
  region        = "${var.aws_region}"
  source_ami_filter {
    filters = {
      name                = "*amzn2-ami-kernel-5.10-hvm-2*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username  = "ec2-user"
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 100 
    throughput            = 1000
    iops                  = 10000
    volume_type           = "gp3"
    delete_on_termination = true
  }
}

build {
  sources = ["source.amazon-ebs.aws-batch-ami"]

  provisioner "ansible" {
    user                = "ec2-user"
    inventory_directory = "${var.inventory_directory}"
    playbook_file       = "${var.playbook_file}"
  }
}
