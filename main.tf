# Define provider, use environment variables
provider "aws" {}

# Definition of variables
variable "ds_admin_pass" {
  type = string
  description = "DC Administrator password"
}
variable "sas_pool" {
  type = string
  description = "IP address pool of SAS"
}
variable "frederik_ip" {
  type = string
  description = "IP address pool of SAS"
}

# Find ami id
data "aws_ami" "AMAZON2" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-hvm-2.0.????????.?-x86_64-gp2"]
  }
  filter {
    name = "state"
    values = ["available"]
  }
}
data "aws_ami" "CENTOS" {
  owners = ["aws-marketplace"]
  most_recent = true
  filter {
    name = "product-code"
    values = ["aw0evgkw8e5c1q413zgy5pjce"]
  }
}

# Resources definiton
resource "aws_vpc" "EC2VPCPIONEER" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_security_group" "SAS" {
  name = "allow_sas"
  description = "Allow incomming traffic from sas"
  vpc_id = aws_vpc.EC2VPCPIONEER.id
  ingress {
    cidr_blocks = [var.sas_pool]
    from_port = 0
    protocol = -1
    to_port = 0
  }
}
resource "aws_security_group" "FREDERIK" {
  name = "allow_frederik"
  description = "Allow incomming traffic from frederik"
  vpc_id = aws_vpc.EC2VPCPIONEER.id
  ingress {
    cidr_blocks = [var.frederik_ip]
    from_port = 0
    protocol = -1
    to_port = 0
  }
}
resource "aws_security_group" "HTTP" {
  name = "allow_http"
  description = "Allow incomming http traffic"
  vpc_id = aws_vpc.EC2VPCPIONEER.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = 6
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
    protocol = 6
  }
}
resource "aws_security_group" "JUPYTER" {
  name = "allow_jupyter"
  description = "Allow incomming https traffic"
  vpc_id = aws_vpc.EC2VPCPIONEER.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 8088
    to_port = 8088
    protocol = 6
  }
}
resource "aws_security_group" "ALL" {
  name = "allow_all"
  description = "Allow all incomming traffic"
  vpc_id = aws_vpc.EC2VPCPIONEER.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    protocol = -1
    to_port = 0
  }
}
resource "aws_internet_gateway" "GW" {
  vpc_id = aws_vpc.EC2VPCPIONEER.id
}
resource "aws_route" "DEFROUTE" {
  route_table_id = aws_vpc.EC2VPCPIONEER.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.GW.id
}
resource "aws_subnet" "EC2SPIONEER00" {
  vpc_id = aws_vpc.EC2VPCPIONEER.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "eu-west-1a"
  depends_on = [aws_internet_gateway.GW]
}
resource "aws_subnet" "EC2SPIONEER01" {
  vpc_id = aws_vpc.EC2VPCPIONEER.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1b"
  depends_on = [aws_internet_gateway.GW]
}
resource "aws_subnet" "EC2SPIONEER02" {
  vpc_id = aws_vpc.EC2VPCPIONEER.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1c"
  depends_on = [aws_internet_gateway.GW]
}
resource "aws_directory_service_directory" "DSPIONEER" {
  name = "piohack.thehyve.net"
  password = var.ds_admin_pass
  size = "Small"
  vpc_settings {
    vpc_id = aws_vpc.EC2VPCPIONEER.id
    subnet_ids = [
      aws_subnet.EC2SPIONEER01.id,
      aws_subnet.EC2SPIONEER02.id
    ]
  }
}
resource "aws_workspaces_directory" "WSWPIONEER" {
  directory_id = aws_directory_service_directory.DSPIONEER.id
}
resource "aws_instance" "EC2SAS" {
  ami = data.aws_ami.AMAZON2.id
  instance_type = "m5.16xlarge"
  key_name = "viyadep"
  vpc_security_group_ids  = [
    aws_vpc.EC2VPCPIONEER.default_security_group_id,
    aws_security_group.SAS.id,
    aws_security_group.HTTP.id,
    aws_security_group.FREDERIK.id
  ]
  subnet_id = aws_subnet.EC2SPIONEER00.id
  depends_on = [aws_internet_gateway.GW]
}
resource "aws_eip" "EIPSAS" {
  vpc = true
  instance = aws_instance.EC2SAS.id
  depends_on = [aws_internet_gateway.GW]
}
resource "aws_ebs_volume" "EBSSAS" {
  availability_zone = "eu-west-1a"
  size = 200
}
resource "aws_instance" "EC2SASCENTOS" {
  ami = data.aws_ami.CENTOS.id
  instance_type = "m5.16xlarge"
  key_name = "viyadep"
  vpc_security_group_ids  = [
    aws_vpc.EC2VPCPIONEER.default_security_group_id,
    aws_security_group.SAS.id,
    aws_security_group.HTTP.id,
    aws_security_group.JUPYTER.id,
    aws_security_group.FREDERIK.id
  ]
  subnet_id = aws_subnet.EC2SPIONEER00.id
  depends_on = [aws_internet_gateway.GW]
}
resource "aws_eip" "EIPSASCENTOS" {
  vpc = true
  instance = aws_instance.EC2SASCENTOS.id
  depends_on = [aws_internet_gateway.GW]
}
resource "aws_ebs_volume" "EBSSASCENTOS" {
  availability_zone = "eu-west-1a"
  size = 200
}
resource "aws_volume_attachment" "EBS2SASCENTOS" {
  device_name = "/dev/xvdb"
  instance_id = aws_instance.EC2SASCENTOS.id
  volume_id = aws_ebs_volume.EBSSASCENTOS.id
}
resource "aws_instance" "EC2PIONEER" {
  ami = data.aws_ami.AMAZON2.id
  instance_type = "t3a.2xlarge"
  key_name = "artur"
  vpc_security_group_ids  = [
    aws_vpc.EC2VPCPIONEER.default_security_group_id,
    aws_security_group.ALL.id
  ]
  subnet_id = aws_subnet.EC2SPIONEER00.id
  depends_on = [aws_internet_gateway.GW]
  root_block_device {
    volume_size = 128
  }
}
resource "aws_eip" "EIPPIONEER" {
  vpc = true
  instance = aws_instance.EC2PIONEER.id
  depends_on = [aws_internet_gateway.GW]
}
