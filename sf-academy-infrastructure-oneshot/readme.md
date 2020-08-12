# Application Infrastructure

### Overview

In this repo you can find terraform code to setup on AWS the entire sf-academy exchange application infrastructure.

### Requirements

- AWS account & configured on the CLI (or simply install aws cli)
- Docker installed

### Get Started

1. `terraform init`
2. `terraform apply`
   and then
3. `terraform destroy`

**Note** The infrastructure is not fully covered by the free tier AWS account, thus some charges on the account will be done. Remember to destroy the infrastructure to avoid further charges.

#### Note

This AWS configuration pull docker images from _docker.io_, if you wanna set up a custom cicd and manage docker image via ECR watch

- [cicd infrastructure](https://github.com/ZhouJian26/sf-academy/tree/master/sf-academy-infrastructure-cicd)
- [application infrastructure](https://github.com/ZhouJian26/sf-academy/tree/master/sf-academy-infrastructure-backend)

### Technology

- Terraform
- AWS
- Docker
