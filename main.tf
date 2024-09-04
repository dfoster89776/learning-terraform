data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "blog_as" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.7.0"
  
  name = "blog"
  min_size = 1
  max_size = 3
  
  vpc_zone_identifier = module.blog_vpc.public_subnets
  security_groups = [module.blog_sg.security_group_id]

  target_group_arns  = [aws_lb_target_group.blog_tg.arn]

  image_id           = data.aws_ami.app_ami.id
  instance_type = var.instance_type

}

resource "aws_lb_target_group" "blog_tg" {
  name        = "blog-tg"
  target_type = "instance"
  port        = 80
  protocol    = "TCP"
  vpc_id      = module.blog_vpc.vpc_id
}

resource "aws_lb_listener" "blog_listener" {
  load_balancer_arn = module.blog_alb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blog_tg.arn
  }
}

module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"
  load_balancer_type = "network"
  enable_deletion_protection = false

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets

  security_groups = [module.blog_sg.security_group_id]

  tags = {
    Environment = "Development"
  }
}

module "blog_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "4.13.0"
  name = "blog"

  vpc_id = module.blog_vpc.vpc_id
  
  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]


}