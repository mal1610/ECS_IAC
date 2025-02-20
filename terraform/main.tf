locals {
  prefix = "malcolm"
}

resource "aws_security_group" "sg_subnet_2" {
  name        = "malcolm_ecs_sg_subnet_2"
  description = "security group for ECS"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "sg_subnet_2_ingress" {
  security_group_id = aws_security_group.sg_subnet_2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "sg_subnet_2_egress" {
  security_group_id = aws_security_group.sg_subnet_2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
}

resource "aws_security_group" "sg_subnet_1" {
  name        = "malcolm_ecs_sg_subnet_1"
  description = "security group for ECS"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "sg_subnet_1_ingress" {
  security_group_id = aws_security_group.sg_subnet_1.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "sg_subnet_1_egress" {
  security_group_id = aws_security_group.sg_subnet_1.id
  from_port = 80
  to_port = 80
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol = "tcp"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "malcolm-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-southeast-1a", "ap-southeast-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
}


resource "aws_ecr_repository" "ecr" {
  name         = "${local.prefix}-ecr"
  force_delete = true
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.9.0"

  cluster_name = "${local.prefix}-ecs"
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    malcolm_taskdef = { #task definition and service name -> #Change
      cpu    = 512
      memory = 1024
      container_definitions = {
        malcolm_flask_app = { #container name -> Change
          essential = true
          image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${local.prefix}-ecr:latest"
          port_mappings = [
            {
              containerPort = 8080
              protocol      = "tcp"
            }
          ]
        }
      }
      assign_public_ip                   = true
      deployment_minimum_healthy_percent = 100
      subnet_ids                   = [module.vpc.public_subnet_objects[0].id, module.vpc.public_subnet_objects[1].id ] #List of subnet IDs to use for your tasks
      security_group_ids           = [aws_security_group.sg_subnet_1.id, aws_security_group.sg_subnet_2.id] #Create a SG resource and pass it here
    }
  }
}
