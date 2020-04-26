# Define provider, use environment variables
provider "aws" {}

# Definition of variables
variable "ds_admin_pass" {
  type = string
  description = "DC Administrator password"
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

# Resources definiton
resource "aws_vpc" "EC2VPCPIONEER" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_security_group" "SSH" {
  name = "allow_ssh"
  description = "Allow incomming ssh traffic"
  vpc_id = aws_vpc.EC2VPCPIONEER.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    protocol = 6
    to_port = 22
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
  key_name = "artur"
  vpc_security_group_ids  = [
    aws_vpc.EC2VPCPIONEER.default_security_group_id,
    aws_security_group.SSH.id
  ]
  subnet_id = aws_subnet.EC2SPIONEER00.id
  depends_on = [aws_internet_gateway.GW]
}
resource "aws_eip" "EIPSAS" {
  vpc = true
  instance = aws_instance.EC2SAS.id
  depends_on = [aws_internet_gateway.GW]
}
