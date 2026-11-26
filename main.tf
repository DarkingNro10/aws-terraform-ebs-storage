terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_security_group" "ebs_sg" {
  name        = "ebs-lab-sg"
  description = "Permite SSH para verificar EBS"

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

resource "aws_instance" "ebs_ec2" {
  ami                    = "ami-01e4a7224fcbfe81f"
  instance_type          = "t3.micro"
  availability_zone      = "us-east-2b"
  vpc_security_group_ids = [aws_security_group.ebs_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              while [ ! -b /dev/nvme1n1 ]; do sleep 2; done
              mkfs -t xfs /dev/nvme1n1
              mkdir -p /data
              mount /dev/nvme1n1 /data
              echo "Datos persistentes en EBS gp3 via Terraform" > /data/prueba.txt
              UUID=$(blkid -s UUID -o value /dev/nvme1n1)
              echo "UUID=$UUID /data xfs defaults,nofail 0 2" >> /etc/fstab
              EOF

  tags = {
    Name = "EC2-EBS-Terraform"
  }
}

resource "aws_ebs_volume" "extra_ebs" {
  availability_zone = "us-east-2b"
  size              = 10
  type              = "gp3"

  tags = {
    Name = "volumen-ebs-terraform"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.extra_ebs.id
  instance_id = aws_instance.ebs_ec2.id
}

output "ebs_instance_id" {
  value = aws_instance.ebs_ec2.id
}

output "ebs_volume_id" {
  value = aws_ebs_volume.extra_ebs.id
}
