data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["{var.environment.network_prefix}.101.0/24", "{var.environment.network_prefix}.102.0/24", "{var.environment.network_prefix}.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "blog_as" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.7.0"
  
  name = "${var.environment.name}-blog"
  min_size = var.min_size
  max_size = var.max_size
  
  vpc_zone_identifier = module.blog_vpc.public_subnets
  security_groups = [module.blog_sg.security_group_id]

  target_group_arns  = [aws_lb_target_group.blog_tg.arn]

  image_id           = data.aws_ami.app_ami.id
  instance_type = var.instance_type

}

resource "aws_lb_target_group" "blog_tg" {
  name        = "${var.environment.name}-blog-tg"
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

  name    = "${var.environment.name}-blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets

  security_groups = [module.blog_sg.security_group_id]

  tags = {
    Environment = var.environment.name
  }
}

module "blog_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "4.13.0"
  name = "${var.environment.name}-blog"

  vpc_id = module.blog_vpc.vpc_id
  
  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]


}