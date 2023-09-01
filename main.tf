provider "aws" {
  region = "us-west-2" # Change to your desired AWS region
}

resource "aws_security_group" "example" {
  name        = "example"
  description = "Example security group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0" # Change to your desired AMI ID
  instance_type = "t2.micro"
  key_name      = var.key_name
  security_groups = [aws_security_group.example.name]

  tags = {
    Name = "example-instance"
  }
}
