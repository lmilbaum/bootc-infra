################################################################################
# SSH Key Pair
################################################################################

resource "aws_key_pair" "this" {
  key_name   = local.project_name
  public_key = file(pathexpand(var.public_key_path))

  tags = {
    Name = "${local.project_name}-key"
  }
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "this" {
  name_prefix = "${local.project_name}-"
  description = "SSH access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"

    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    cidr_blocks = [
      "${chomp(data.http.my_ip.response_body)}/32"
    ]
  }

  egress {
    description = "Outbound"

    protocol  = "-1"
    from_port = 0
    to_port   = 0

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "${local.project_name}-sg"
  }
}

################################################################################
# EC2
################################################################################

resource "aws_instance" "this" {
  ami           = data.aws_ami.fedora.id
  instance_type = "t4g.small"

  subnet_id              = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.this.id]

  key_name = aws_key_pair.this.key_name

  associate_public_ip_address = true

  user_data_replace_on_change = true
  user_data                   = file("${path.module}/cloud-init.yaml")

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 12
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = local.project_name
  }
}