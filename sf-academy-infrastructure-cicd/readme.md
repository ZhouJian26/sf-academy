# Application CICD Infrastructure

### Overview

In this repo you can find terraform code to setup on AWS the entire sf-academy exchange application CICD infrastructure.

### Requirements

- AWS account & configured on the CLI (or simply install aws cli)
- A file in this folder that contains those variables
  |variable name|type|description|
  | :- | :-: | :- |
  |aws_region|string|Target AWS region
  |github_token|string| GH token used to trigger codebuild
  |github_username|string| GH username used in codebuild
  |webapp_bucket|string| The name for the web application S3 bucket
  |gh_webapp_url|string|GH url to the web application repo. ([webapplication](https://github.com/ZhouJian26/sf-academy-webapp))
  |gh_repo_docker_img|map|A map of all GH repo where is need to build a docker image and then upload into a ECR repository ([nginx](https://github.com/ZhouJian26/sf-academy-nginx), [api](https://github.com/ZhouJian26/sf-academy-api), [exchange](https://github.com/ZhouJian26/sf-academy-exchange-microservice), [user](https://github.com/ZhouJian26/sf-academy-user-microservice))

### Get Started

1. `terraform init`
2. `terraform apply`
   and then
3. `terraform destroy`

**Note** The infrastructure is not fully covered by the free tier AWS account, thus some charges on the account will be done. Remember to destroy the infrastructure to avoid further charges.

### Output

- S3 url to the webapplication
- ECR url to the docker images

### Technology

- Terraform
- AWS
