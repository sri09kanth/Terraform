provider "aws" {
  region = "us-west-2" # Change to your desired AWS region
}

# Create a VPC with public and private subnets
module "vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  name            = "webapp-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# Create a security group for the EC2 instances
resource "aws_security_group" "webapp_sg" {
  name        = "webapp-sg"
  description = "Security group for web application"
  vpc_id      = module.vpc.vpc_id

  # Define your ingress and egress rules here
  # Example:
  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
}

# Create an RDS instance for the web application
module "rds" {
  source      = "terraform-aws-modules/rds/aws"
  identifier  = "webapp-db"
  name        = "webapp-db"
  engine      = "mysql"
  engine_version = "5.7"
  instance_class = "db.t2.micro"
  allocated_storage = 20
  username    = "webappuser"
  password    = "your-password"
  vpc_security_group_ids = [aws_security_group.webapp_sg.id]
  skip_final_snapshot = true
}

# Create an Auto Scaling Group and Launch Configuration for the web application
resource "aws_launch_configuration" "webapp_lc" {
  name_prefix          = "webapp-lc-"
  image_id             = "ami-0c55b159cbfafe1f0" # Replace with your desired AMI
  instance_type        = "t2.micro"
  security_groups      = [aws_security_group.webapp_sg.id]
  key_name             = var.key_name
  user_data            = file("userdata.sh")
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "webapp_asg" {
  name                  = "webapp-asg"
  launch_configuration = aws_launch_configuration.webapp_lc.name
  min_size              = 2
  max_size              = 5
  desired_capacity      = 2
  vpc_zone_identifier   = module.vpc.private_subnets

  # Define additional Auto Scaling settings here
}

# Create an Elastic Load Balancer (ELB) for the web application
resource "aws_lb" "webapp_lb" {
  name               = "webapp-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  enable_http2        = true
  enable_cross_zone_load_balancing = true

  security_groups = [aws_security_group.webapp_sg.id]
}

resource "aws_lb_listener" "webapp_listener" {
  load_balancer_arn = aws_lb.webapp_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      content      = "OK"
    }
  }
}

# Output the DNS name of the ELB
output "elb_dns_name" {
  description = "DNS name of the Elastic Load Balancer (ELB)"
  value       = aws_lb.webapp_lb.dns_name
}
