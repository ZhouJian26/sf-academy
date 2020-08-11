variable aws_region{
  type = string
}
variable repositories{
  type = map
}
variable github_token{
  type = string
}
variable github_username{
  type = string
}

resource "aws_iam_role" "_" {
  for_each = var.repositories
  
  name = "sf-academy-${each.value.image_name}"

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
  for_each = var.repositories

  role = aws_iam_role._[each.key].name

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
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_codebuild_project" "_" {
  for_each = var.repositories
  name          = "sf-academy-${each.value.image_name}"
  description   = "Build docker image and push it into ECR"
  build_timeout = "5"
  service_role  = aws_iam_role._[each.key].arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository._[each.key].name
    }

    environment_variable {
      name = "ECR_URL"
      value = aws_ecr_repository._[each.key].repository_url
    }

    environment_variable {
      name = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  source {
    type            = "GITHUB"
    location        = each.value.git_url
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
      group_name  = "codebuild/sf-academy-log-${each.value.image_name}"
    }
  }
  tags = {
    Project = "sf-academy"
  }
}

resource "aws_codebuild_webhook" "_" {
  for_each = var.repositories

  project_name = aws_codebuild_project._[each.key].name
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

resource "aws_ecr_repository" "_" {
  for_each = var.repositories
  name = "sf-academy-${each.value.image_name}"

  image_scanning_configuration {
    scan_on_push = false
  }
}
resource "aws_ecr_lifecycle_policy" "_" {
  for_each = var.repositories

  repository = aws_ecr_repository._[each.key].name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 3 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 3
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}


resource "aws_ecr_repository_policy" "_" {
  for_each = var.repositories
  repository = aws_ecr_repository._[each.key].name

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "new policy",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "ecr:GetRepositoryPolicy",
                "ecr:ListImages",
                "ecr:DeleteRepository",
                "ecr:BatchDeleteImage",
                "ecr:SetRepositoryPolicy",
                "ecr:DeleteRepositoryPolicy"
            ]
        }
    ]
}
EOF
}

resource "aws_cloudwatch_log_group" "backend" {
  for_each = var.repositories
  name = "codebuild/sf-academy-log-${each.value.image_name}"
  retention_in_days = 1
}

output ecr_repo_arn {
  value       = {
    for ecr_repo in var.repositories:
    ecr_repo.image_name => aws_ecr_repository._[ecr_repo.image_name].repository_url
  }
  description = "ECR docker image arn"
}


