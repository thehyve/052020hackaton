# Define provider, use environment variables
provider "aws" {}

# Definition of variables
variable "ds_admin_pass" {
  type = string
  description = "DC Administrator password"
}

# Resources definiton
resource "aws_vpc" "EC2VPCPIONEER" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_subnet" "EC2SPIONEER01" {
  vpc_id = "${aws_vpc.EC2VPCPIONEER.id}"
  cidr_block = "10.0.1.0/24"
}
resource "aws_subnet" "EC2SPIONEER02" {
  vpc_id = "${aws_vpc.EC2VPCPIONEER.id}"
  cidr_block = "10.0.2.0/24"
}
resource "aws_directory_service_directory" "DSPIONEER" {
  name = "piohack.thehyve.net"
  password = "${var.ds_admin_pass}"
  size = "Small"
  vpc_settings {
    vpc_id = "${aws_vpc.EC2VPCPIONEER.id}"
    subnet_ids = [
      "${aws_subnet.EC2SPIONEER01.id}",
      "${aws_subnet.EC2SPIONEER02.id}"
    ]
  }
}
resource "aws_workspaces_directory" "WSWPIONEER" {
  directory_id = "${aws_directory_service_directory.DSPIONEER.id}"
}
