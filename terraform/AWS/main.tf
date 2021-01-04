terraform {
  required_version = ">= 0.12, < 0.15, < 1.0"
}

provider "aws" {
  region = var.region
}

resource "tls_private_key" "keygen" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.keygen.public_key_openssh
}

resource "aws_vpc" "basecamp" {
  cidr_block = var.basecamp_vpc_cidr_block

  tags = {
    Name = "basecamp VPC"
  }
}

#------------------------------------------------------------
# Security Groups
#------------------------------------------------------------

resource "aws_security_group" "bastion_access_sg" {
  name        = "Allow ssh"
  description = "Allow inbound ports from Management IPs"
  vpc_id      = aws_vpc.basecamp.id

  dynamic "ingress" {
    for_each = var.bastion_in_allowed_ports
    content {
      description = "Allow Inbound from Management Subnets and Ports"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.bastion_in_allowed_subnets
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bastion_Srv IN Security Group"
  }
}

resource "aws_security_group" "alb_access_sg" {
  name        = "Allow http and https"
  description = "Allow inbound ports from Dedicated Subnets"
  vpc_id      = aws_vpc.basecamp.id

  dynamic "ingress" {
    for_each = var.alb_in_allowed_ports
    content {
      description = "Access from Dedicated Subnets"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.alb_in_allowed_subnets
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB IN Security Group"
  }
}

resource "aws_security_group" "worker_access_sg" {
  name        = "From ALB and Bastion only"
  description = "Allow inbound traffic from ALB and Bastion Host only"
  vpc_id      = aws_vpc.basecamp.id

  ingress {
    description     = "Access from Bastion_srv"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.bastion_access_sg.id, aws_security_group.alb_access_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Worker_Srv IN Security Group"
  }
}

#------------------------------------------------------------
# SUBNETS
#------------------------------------------------------------

resource "aws_subnet" "public_subnet_az0" {
  vpc_id                  = aws_vpc.basecamp.id
  cidr_block              = var.public_subnet_cidr_block_az0
  availability_zone       = data.aws_availability_zones.available_azs.names[0]
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.igw]

  tags = {
    Name = "basecamp Pub Subnet in ${data.aws_availability_zones.available_azs.names[0]}"
  }
}

resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.basecamp.id
  cidr_block              = var.public_subnet_cidr_block_az1
  availability_zone       = data.aws_availability_zones.available_azs.names[1]
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.igw]

  tags = {
    Name = "basecamp Pub Subnet 2 in ${data.aws_availability_zones.available_azs.names[1]}"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.basecamp.id
  cidr_block        = var.private_subnet_cidr_block
  availability_zone = data.aws_availability_zones.available_azs.names[0]

  tags = {
    Name = "basecamp Priv Subnet in ${data.aws_availability_zones.available_azs.names[0]}"
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.basecamp.id
  cidr_block        = var.private_subnet_cidr_block_az1
  availability_zone = data.aws_availability_zones.available_azs.names[1]

  tags = {
    Name = "basecamp Priv Subnet in ${data.aws_availability_zones.available_azs.names[1]}"
  }
}

#------------------------------------------------------------
# EIP for Bastion
#------------------------------------------------------------
resource "aws_eip" "eip_ip_bastion" {
  vpc        = true
  instance   = aws_instance.bastion_srv.id
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "eip_ip_nat_gw" {
  vpc        = true
}

#------------------------------------------------------------
# IGW
#------------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.basecamp.id

  tags = {
    Name = "IGW for basecamp VPC"
  }
}

#------------------------------------------------------------
# NAT GW
#------------------------------------------------------------
resource "aws_nat_gateway" "nat_gw_az0" {
  allocation_id = aws_eip.eip_ip_nat_gw.id
  subnet_id = aws_subnet.public_subnet_az0.id
  depends_on = [aws_internet_gateway.igw]
}

#------------------------------------------------------------
# ROUTING
#------------------------------------------------------------

resource "aws_route_table" "pub_subnet_route_table_az0" {
  vpc_id = aws_vpc.basecamp.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "Public Subnet Route table AZ0"
  }
}

resource "aws_route_table" "pub_subnet_route_table_az1" {
  vpc_id = aws_vpc.basecamp.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "Public Subnet Route table AZ1"
  }
}

resource "aws_route_table" "private_subnet_route_table_nat" {
  vpc_id = aws_vpc.basecamp.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_az0.id
  }

  tags = {
    Name = "Private Subnet Route table for NAT GW in Private Subnet"
  }
}

resource "aws_route_table_association" "public_subnet_az0_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet_az0.id
  route_table_id = aws_route_table.pub_subnet_route_table_az0.id
}

resource "aws_route_table_association" "public_subnet_az1_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.pub_subnet_route_table_az1.id
}

resource "aws_route_table_association" "private_subnet_az0_nat_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_subnet_route_table_nat.id
}

resource "aws_route_table_association" "private_subnet_az1_nat_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_subnet_route_table_nat.id
}

#------------------------------------------------------------
# INSTANCES
#------------------------------------------------------------
resource "aws_instance" "bastion_srv" {
  ami             = data.aws_ami.latest_ubuntu.image_id
  instance_type   = var.bastion_instance_type
  private_ip      = var.bastion_instance_private_ip
  subnet_id       = aws_subnet.public_subnet_az0.id
  key_name        = aws_key_pair.generated_key.key_name
  security_groups = [aws_security_group.bastion_access_sg.id]

  tags = {
    Name = "Bastion Server"
  }
}

resource "aws_instance" "worker_srv" {
  ami             = data.aws_ami.latest_ubuntu.image_id
  instance_type   = var.worker_instance_type
  private_ip      = var.worker_instance_private_ip
  subnet_id       = aws_subnet.private_subnet.id
  key_name        = aws_key_pair.generated_key.key_name
  security_groups = [aws_security_group.worker_access_sg.id]
  availability_zone = data.aws_availability_zones.available_azs.names[0]
  user_data = <<EOF
#!/bin/sh
sudo apt-get -y update
sudo apt-get -y install nginx
echo "<h2>WebServer 1</h2><br>Build by Terraform!" > /var/www/html/index.html
sudo service nginx start
chkconfig nginx on
EOF
  tags = {
    Name = "Worker Server"
  }
}

resource "aws_instance" "worker_srv2" {
  ami             = data.aws_ami.latest_ubuntu.image_id
  instance_type   = var.worker_instance_type
  private_ip      = var.worker_instance2_private_ip
  subnet_id       = aws_subnet.private_subnet2.id
  key_name        = aws_key_pair.generated_key.key_name
  security_groups = [aws_security_group.worker_access_sg.id]
  availability_zone = data.aws_availability_zones.available_azs.names[1]
  user_data = <<EOF
#!/bin/sh
sudo apt-get -y update
sudo apt-get -y install nginx
echo "<h2>WebServer 2</h2><br>Build by Terraform!" > /var/www/html/index.html
sudo service nginx start
chkconfig nginx on
EOF
  tags = {
    Name = "Worker Server"
  }
}

#---------------------------------------------------
# ALB
#---------------------------------------------------

resource "aws_lb" "alb" {
  name                = var.alb_name
  security_groups     = [aws_security_group.alb_access_sg.id]
  subnet_mapping {
    subnet_id          = aws_subnet.public_subnet_az0.id
  }
  subnet_mapping {
    subnet_id          = aws_subnet.public_subnet_az1.id
  }

  internal            = false
  enable_deletion_protection  = false
  load_balancer_type          = "application"

#  access_logs         = [S3 Bucket arn and other params, but we don't use it in this case]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name            = var.alb_name
    Environment     = var.environment
  }
}

#---------------------------------------------------
# LB target group
#---------------------------------------------------
resource "aws_lb_target_group" "alb_target_group" {
  name                 = var.alb_target_gr_name
  port                 = var.worker_backend_port
  protocol             = var.worker_backend_protocol
  vpc_id               = aws_vpc.basecamp.id
  target_type          = var.target_type

  tags = {
    Name            = var.alb_name
    Environment     = var.environment
  }
}

#  It's possible to use complex health checks like below, but we don't use it in this case
//  health_check {
//    interval            =
//    path                =
//    port                =
//    healthy_threshold   =
//    unhealthy_threshold =
//    timeout             =
//    protocol            =
//    matcher             =
//  }
//}

#---------------------------------------------------
# LB listeners
#---------------------------------------------------
resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn   = aws_lb.alb.arn
  port                = "80"
  protocol            = "HTTP"
  default_action {
    type                = "forward"
    target_group_arn    = aws_lb_target_group.alb_target_group.arn
  }

  depends_on = [aws_lb.alb, aws_lb_target_group.alb_target_group]
}


#---------------------------------------------------
# LB target group attachment
#---------------------------------------------------
resource "aws_lb_target_group_attachment" "alb_target_group_attachment" {
  target_group_arn    = aws_lb_target_group.alb_target_group.arn
  target_id           = aws_instance.worker_srv.id
  port                = var.worker_backend_port

  depends_on = [aws_lb.alb, aws_lb_target_group.alb_target_group]
}

resource "aws_lb_target_group_attachment" "alb_target_group_attachment2" {
  target_group_arn    = aws_lb_target_group.alb_target_group.arn
  target_id           = aws_instance.worker_srv2.id
  port                = var.worker_backend_port

  depends_on = [aws_lb.alb, aws_lb_target_group.alb_target_group]
}