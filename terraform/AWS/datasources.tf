data "aws_availability_zones" "available_azs" {
  state = "available"
}

data "aws_ami" "latest_ubuntu" {
  most_recent = "true"
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-*"]
  }
}
