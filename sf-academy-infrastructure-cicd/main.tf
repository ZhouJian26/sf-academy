variable  aws_region {}
variable  gh_repo_docker_img {}
variable  github_token {}
variable  github_username{}
variable webapp_bucket{}
variable gh_webapp_url{}

provider "aws" {
  version = "~> 3.0"
  region = var.aws_region
}

module "webapp" {
  source = "./webapp-s3"
  gh_webapp_url = var.gh_webapp_url
  webapp_bucket = var.webapp_bucket
  aws_region = var.aws_region
  github_token = var.github_token
  github_username = var.github_username
}

module "codebuild_docker" {

  source = "./codebuild-docker-image"

  repositories = var.gh_repo_docker_img
  aws_region = var.aws_region
  github_token = var.github_token
  github_username = var.github_username
}

output ecr_repo_arn {
  value = module.codebuild_docker.ecr_repo_arn
}

output aws_webapp_url {
  value = module.webapp.webapp_url
}