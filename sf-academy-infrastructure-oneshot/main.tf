provider "aws" {
  region = var.aws_region
}
terraform {
  required_version = ">= 0.12"
}

### S3 Webapp

data "template_file" "webapp_policy" {
  template = file("./s3-webapp-policy.json")

  vars = {
    s3_name = var.webapp_bucket
  }
}

resource "aws_s3_bucket" "webapp_bucket" {
  bucket = var.webapp_bucket
  acl = "public-read"
  policy = data.template_file.webapp_policy.rendered
  force_destroy = true
  
  website {
    index_document = "index.html"
    error_document = "error.html"
    
  }
}

resource "null_resource" "webapp_init" {
  depends_on = [aws_s3_bucket.webapp_bucket]

  provisioner "local-exec" {
      command = <<EOT
        cd ../sf-academy-webapp/ && \
        npm run build && \
        aws s3 rm s3://${aws_s3_bucket.webapp_bucket.bucket}/ && \
        aws s3 mv out s3://${aws_s3_bucket.webapp_bucket.bucket}/ --recursive && \
        rm -rf out
      EOT
  }
}

### Network

data "aws_availability_zones" "available" {
    state = "available"
}

resource "aws_vpc" "main" {
    cidr_block = "10.10.0.0/16"
    enable_dns_hostnames = true
}

resource "aws_subnet" "main" {
    vpc_id = aws_vpc.main.id
    count = var.az_count
    cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
    availability_zone = data.aws_availability_zones.available.names[count.index]
    map_public_ip_on_launch = true

    depends_on = [aws_vpc.main]
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.main.id

    depends_on = [aws_vpc.main]
}

resource "aws_route_table" "r" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table_association" "a" {
    count = var.az_count
    subnet_id = element(aws_subnet.main.*.id, count.index)
    route_table_id = aws_route_table.r.id

    depends_on = [aws_route_table.r]
}


## Security

resource "aws_security_group" "alb" {
    description = "controls assess to the application ELB"
    vpc_id = aws_vpc.main.id
    name = "sf-academy-ecs-lb"
    
    ingress {
        protocol = "tcp"
        from_port = 80
        to_port = 80
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        protocol = -1
        from_port = 0
        to_port = 0
        cidr_blocks = aws_subnet.main.*.cidr_block
    }

    depends_on = [aws_subnet.main]
}

resource "aws_security_group" "ec2" {
    description = "controls direct access to application istance"
    vpc_id = aws_vpc.main.id
    name = "sf-academy-ec2-istance"

    ingress {
        protocol = -1
        from_port = 0
        to_port = 0
        security_groups = [aws_security_group.alb.id]
    }

    egress {
        protocol = -1
        from_port = 0
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
    }

    depends_on = [aws_security_group.alb]
}

resource "aws_security_group" "rds" {
    description = "controls direct access to RDS"
    vpc_id = aws_vpc.main.id
    name = "sf-academy-rds-user"

    ingress {
        protocol = "tcp"
        from_port = 3306
        to_port = 3306
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        protocol = "tcp"
        from_port = 0
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
    }

    depends_on = [aws_security_group.alb]
}

## EC2

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["amazon", "self"]
}

resource "aws_launch_configuration" "ec2" { 
    iam_instance_profile = aws_iam_instance_profile.backend.name
    security_groups = [aws_security_group.ec2.id]
    image_id = data.aws_ami.amazon_linux.id
    instance_type = var.instance_type
    name_prefix = "sf-academy-"
    spot_price = "0.004"
    associate_public_ip_address = true

    lifecycle {
        create_before_destroy = true
    } 
    user_data = <<EOF
#! /bin/bash
echo "ECS_CLUSTER=${var.cluster_name}" >> /etc/ecs/ecs.config
EOF 

    depends_on = [
      aws_security_group.ec2,
      aws_iam_instance_profile.backend,
      aws_route_table_association.a
    ]
}

resource "aws_autoscaling_group" "asg" {
    name = "sf-academy-asg"
    vpc_zone_identifier = aws_subnet.main.*.id
    min_size = var.asg_min
    max_size = var.asg_max
    desired_capacity = var.asg_desired
    launch_configuration = aws_launch_configuration.ec2.name
    target_group_arns = [aws_alb_target_group.backend.arn]
    health_check_type = "ELB"

    depends_on = [
      aws_subnet.main,
      aws_route_table_association.a  
    ]

    tag {
        key = "AmazonECSManaged" 
        value = ""
        propagate_at_launch = true 
    }
}


## ALB

resource "aws_alb_target_group" "backend" {
    name = "sf-academy-ecs-backend"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main.id

    health_check {
      healthy_threshold = 2
      unhealthy_threshold = 2
      timeout = 3
      path = "/albcheck"
      interval = 30
    }

    depends_on = [aws_alb.main]
}

resource "aws_alb" "main" {
    name = "sf-academy-alb-ecs-backend"
    subnets = aws_subnet.main.*.id
    security_groups = [aws_security_group.alb.id]
    load_balancer_type = "application"
    internal = false

    depends_on = [aws_security_group.alb]
}

resource "aws_alb_listener" "backend" {
    load_balancer_arn = aws_alb.main.id
    port = 80
    protocol = "HTTP"

    default_action {
        type = "forward"
        target_group_arn = aws_alb_target_group.backend.arn
    }

    depends_on = [aws_alb_target_group.backend]
}

## IAM

### EC2 

resource "aws_iam_instance_profile" "backend" {
    name_prefix = "sf-academy-"
    role = aws_iam_role.backend.name
}

resource "aws_iam_role" "backend" {
  name_prefix = "sf-academy-"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
            "ec2.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "backend" {
  role       = aws_iam_role.backend.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

### ECS

resource "aws_iam_role" "ecs_service" {
  name_prefix = "sf-academy-ecs-"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
            "ecs.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_service" {
  role       = aws_iam_role.ecs_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

## ECS

resource "aws_ecs_cluster" "main" {
    name = var.cluster_name
    capacity_providers = [aws_ecs_capacity_provider._.name]

    provisioner "local-exec" {
    when = destroy

    command = <<CMD
      # Get the list of capacity providers associated with this cluster
      CAP_PROVS="$(aws ecs describe-clusters --clusters "${self.arn}" \
        --query 'clusters[*].capacityProviders[*]' --output text)"

      # Now get the list of autoscaling groups from those capacity providers
      ASG_ARNS="$(aws ecs describe-capacity-providers \
        --capacity-providers "$CAP_PROVS" \
        --query 'capacityProviders[*].autoScalingGroupProvider.autoScalingGroupArn' \
        --output text)"

      if [ -n "$ASG_ARNS" ] && [ "$ASG_ARNS" != "None" ]
      then
        for ASG_ARN in $ASG_ARNS
        do
          ASG_NAME=$(echo $ASG_ARN | cut -d/ -f2-)

          # Set the autoscaling group size to zero
          aws autoscaling update-auto-scaling-group \
            --auto-scaling-group-name "$ASG_NAME" \
            --min-size 0 --max-size 0 --desired-capacity 0

          # Remove scale-in protection from all instances in the asg
          INSTANCES="$(aws autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$ASG_NAME" \
            --query 'AutoScalingGroups[*].Instances[*].InstanceId' \
            --output text)"
          aws autoscaling set-instance-protection --instance-ids $INSTANCES \
            --auto-scaling-group-name "$ASG_NAME" \
            --no-protected-from-scale-in
        done
      fi
CMD
  }
}

resource "aws_ecs_capacity_provider" "_" {
    name = "sf-academy-capacity-provider"
    auto_scaling_group_provider {
        auto_scaling_group_arn = aws_autoscaling_group.asg.arn
        managed_scaling {
            status          = "ENABLED"
            target_capacity = 85
        }
    }

    depends_on = [
      aws_autoscaling_group.asg
    ]
}

resource "random_string" "jwt_key" {
  length = 512
}

data "template_file" "container_definition_backend" {
    template = file("container-definitions/backend.json")

    vars = {
      DB_HOST = aws_db_instance.main.address
      DB_USER = aws_db_instance.main.username
      DB_PASSWORD = aws_db_instance.main.password
      DB_DATABASE = "sf_academy_exchange_db"
      JWT_KEY = random_string.jwt_key.result
      WEBAPPURL = "http://${aws_s3_bucket.webapp_bucket.website_endpoint}"
      nginx_image = var.nginx_image
      api_image = var.api_image
      exchange_image = var.exchange_image
      user_image = var.user_image
    }
}

resource "aws_ecs_task_definition" "backend_task" {
    family = "sf-academy-backend-task"
    container_definitions = data.template_file.container_definition_backend.rendered
    network_mode = "bridge"
    requires_compatibilities = ["EC2"]
}

resource "aws_ecs_service" "backend_service" {
    name = "sf-academy-backend-service" 
    cluster = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.backend_task.arn
    desired_count = var.backend_service_desired
    iam_role = aws_iam_role.ecs_service.arn

    force_new_deployment = true

    load_balancer {
        target_group_arn = aws_alb_target_group.backend.arn
        container_name = "nginx_server"
        container_port = 80
    }

    depends_on = [
        aws_iam_role.ecs_service,
        aws_alb_target_group.backend,
        aws_ecs_cluster.main,
        aws_ecs_task_definition.backend_task
    ]
}

## RDS

resource "random_string" "rds_username" {
  length = 12
  number = false
  special = false
}
resource "random_string" "rds_pw" {
  length = 32
  special = false
}

resource "aws_db_instance" "main" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t2.small"
  name                 = "sf_academy_exchange_db"
  username             = random_string.rds_username.result
  password             = random_string.rds_pw.result
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot = true
  publicly_accessible = true

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name = aws_db_subnet_group.main.id 

  depends_on = [
    aws_security_group.rds,
    aws_db_subnet_group.main
  ]
}

resource "aws_db_subnet_group" "main" {
  name = "main_subnet_group"
  description = "Main group of subnets"
  subnet_ids = aws_subnet.main.*.id
  depends_on = [
    aws_subnet.main
  ]
} 

## RDS Init

resource "null_resource" "db_setup" {

  depends_on = [aws_db_instance.main, aws_security_group.rds]

    provisioner "local-exec" {
        command = <<EOT
          cd ../sf-academy-user-db/ && \
          docker build -t sf-academy-db-init . -f Dockerfile-init && \
          docker run -e address=${aws_db_instance.main.address} -e username=${aws_db_instance.main.username} -e password=${aws_db_instance.main.password} -e name=${aws_db_instance.main.name} sf-academy-db-init
        EOT
    }
}

## CloudWatch

resource "aws_cloudwatch_log_group" "backend" {
  name = "sf-academy-ecs-group/backend"
  retention_in_days = 1
}
## Output

output application_url {
  value = aws_alb.main.dns_name
}