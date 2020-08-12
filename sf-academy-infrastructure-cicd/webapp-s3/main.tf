variable aws_region{
  type = string
}
variable gh_webapp_url{
  type = string
}
variable github_token{
  type = string
}
variable github_username{
  type = string
}
variable webapp_bucket{
    type = string
}
output webapp_url {
  value       = aws_s3_bucket.webapp_bucket.website_endpoint
}

data "template_file" "webapp_policy" {
  template = file("${path.module}/webapp-policy.json")

  vars = {
    s3_name = var.webapp_bucket
    codebuild_arn = aws_iam_role._.arn
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

resource "aws_iam_role" "_" {
  
  name = "sf-academy-s3-webapp"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "_" {

  role = aws_iam_role._.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.webapp_bucket.arn}",
        "${aws_s3_bucket.webapp_bucket.arn}/*"
      ]
    }
  ]
}
POLICY
}


resource "aws_codebuild_project" "_" {
  name          = "sf-academy-s3-webapp"
  description   = "Build webapp and push to S3"
  build_timeout = "5"
  service_role  = aws_iam_role._.arn

  artifacts {
    type = "S3"
    encryption_disabled = true
    location = var.webapp_bucket
    packaging = "NONE"
    name = "/"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  source {
    type            = "GITHUB"
    location        = var.gh_webapp_url
    git_clone_depth = 1

    auth {
      type     = "OAUTH"
      resource = aws_codebuild_source_credential._.arn
    }
    git_submodules_config {
      fetch_submodules = true
    }
  }

  source_version = "master"

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild/sf-academy-log-s3-webapp"
    }
  }
  tags = {
    Project = "sf-academy"
  }
}
resource "aws_codebuild_webhook" "_" {

  project_name = aws_codebuild_project._.name
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "master"
    }
  }
}
resource "aws_codebuild_source_credential" "_" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_token
  user_name   = var.github_username
}
resource "aws_cloudwatch_log_group" "backend" {
  name = "codebuild/sf-academy-log-s3-webapp"
  retention_in_days = 1
}