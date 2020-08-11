# Application Infrastructure

### Overview

In this repo you can find terraform code to setup on AWS the entire sf-academy exchange application infrastructure.

### Requirements

- AWS account & configured on the CLI (or simply install aws cli)
- Docker installed
- A file in this folder that contains those variables
  |variable name|type|description|
  | :- | :-: | :- |
  |webapp_url|string|S3 url to the web application
  |rds_username|string| RDS username
  |rds_password|string| RDS password
  |nginx_image|string| ECR nginx docker image url
  |api_image|string|ECR api_image docker image url
  |exchange_image|string|ECR exchange_image docker image url
  |user_image|string|ECR user_image docker image url

### Get Started

1. `terraform init`
2. `terraform apply`
   and then
3. `terraform destroy`

**Note** The infrastructure is not fully covered by the free tier AWS account, thus some charges on the account will be done. Remember to destroy the infrastructure to avoid further charges.

### Technology

- Terraform
- AWS
- Docker
