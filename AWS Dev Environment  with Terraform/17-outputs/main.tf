resource "aws_vpc" "shd_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "shd_public_subnet" {
  vpc_id                  = aws_vpc.shd_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "shd_internet_gateway" {
  vpc_id = aws_vpc.shd_vpc.id

  tags = {
    Name = "shd_igw"
  }
}

resource "aws_route_table" "shd_public_rt" {
  vpc_id = aws_vpc.shd_vpc.id

  tags = {
    Name = "dev_public_rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.shd_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.shd_internet_gateway.id
}

resource "aws_route_table_association" "shd_public_assoc" {
  subnet_id      = aws_subnet.shd_public_subnet.id
  route_table_id = aws_route_table.shd_public_rt.id
}

resource "aws_security_group" "shd_sg" {
  name        = "public_sg"
  description = "public security group"
  vpc_id      = aws_vpc.shd_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_key_pair" "shd_auth" {
  key_name   = "shdkey2"
  public_key = file("~/.ssh/shdkey.pub")
}

resource "aws_instance" "dev_node" {
    instance_type = "t2.micro"
    ami = data.aws_ami.server_ami.id
    key_name = aws_key_pair.shd_auth.id 
    vpc_security_group_ids = [aws_security_group.shd_sg.id]
    subnet_id = aws_subnet.shd_public_subnet.id
    user_data = file("userdata.tpl")

    root_block_device {
        volume_size = 10
    }
    
    tags = {
        Name = "dev-node"
    }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname = self.public_ip,
      user     = "ubuntu",
    identityfile = "~/.ssh/shdkey" })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }
}