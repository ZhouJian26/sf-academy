variable  aws_region {
  type        = string
  default     = "eu-central-1"
  description = "The AWS region to create things in."
}

variable az_count {
  type        = number
  default     = 2
  description = "Number of AZs to cover in a given AWS region"
}

variable instance_type {
  type        = string
  default     = "t2.micro"
  description = "AWS instance type"
}

variable asg_min {
  type        = number
  default     = 1
  description = "Min numbers of servers in ASG"
}

variable asg_max {
  type        = number
  default     = 5
  description = "Max numbers of servers in ASG"
}

variable asg_desired {
  type        = number
  default     = 1
  description = "Desired numbers of servers in ASG"
}

variable backend_service_desired {
  type        = number
  default     = 1
  description = "Desired numbers of backend task in ECS"
}

variable cluster_name {
  type        = string
  default     = "sf-academy-ecs-cluster"
  description = "Cluster ecs name"
}

variable nginx_image {
  type        = string
  default     = "zhou0998/sf_academy_exchange_app_nginx:latest"
}
variable api_image {
  type        = string
  default     = "zhou0998/sf_academy_exchange_app_api:latest"
}
variable exchange_image {
  type        = string
  default     = "zhou0998/sf_academy_exchange_app_exchange_microservice:latest"
}
variable user_image {
  type        = string
  default     = "zhou0998/sf_academy_exchange_app_user_microservice:latest"
}

variable webapp_bucket {
  type        = string
  default     = "sf-academy-oneshot"
  description = "Webapp bucket name"
}
