resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "task-tracker-dev-vpc"
  }
}

resource "aws_subnet" "public_a" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"

  tags = {
    Name = "task-tracker-dev-public-subnet-a"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "task-tracker-dev-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "task-tracker-dev-public-rt"
  }
}

resource "aws_route" "default_route" {

  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "app_sg" {
  name        = "task-tracker-dev-app-sg"
  description = "Dev security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "task-tracker-dev-app-sg"
  }

}

resource "aws_vpc_security_group_ingress_rule" "app_port" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8000
  ip_protocol       = "tcp"
  to_port           = 8000

}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = var.my_ip
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22

}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


resource "aws_key_pair" "auth" {

  key_name   = "task-tracker-dev-key"
  public_key = file("~/.ssh/task-tracker-key.pub")
}

resource "aws_instance" "app" {

  instance_type          = "t3.micro"
  ami                    = data.aws_ami.ubuntu.id
  key_name               = aws_key_pair.auth.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  subnet_id              = aws_subnet.public_a.id
  user_data              = templatefile("userdata.tpl", { image = var.image, db_password = var.db_password })
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "task-tracker-dev-app"
  }
}

# Creating badge and who may use it (trust policy)
resource "aws_iam_role" "ssm" {

  name = "task-tracker-dev-ec2-ssm-role"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach AWS's ready-made Systems Manager permissions to that badge
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

}

resource "aws_iam_instance_profile" "ssm" {

  name = "task-tracker-dev-ec2-profile"
  role = aws_iam_role.ssm.name

}
