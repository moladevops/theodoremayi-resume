terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket that serves the site"
  type        = string
  default     = "s3schoolstatic"
}

variable "distribution_id" {
  description = "CloudFront distribution in front of the bucket"
  type        = string
  default     = "E1G4CZAO00R8D6"
}

variable "github_repository" {
  description = "Repository allowed to deploy, as owner/name"
  type        = string
  default     = "moladevops/theodoremayi-resume"
}

# GitHub's OIDC subject includes the immutable owner and repository IDs:
# repo:<owner>@<owner_id>/<repo>@<repo_id>:environment:<environment>
variable "github_oidc_subject" {
  description = "Exact sub claim of the deploy job's OIDC token (shown by the workflow's debug step)"
  type        = string
  default     = "repo:moladevops@224841099/theodoremayi-resume@1453049398:environment:production"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set to false if the AWS account already has one."
  type        = bool
  default     = true
}

data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "site" {
  bucket = var.bucket_name
}

data "aws_cloudfront_distribution" "site" {
  id = var.distribution_id
}

# Lets GitHub Actions prove its identity to AWS: no AWS keys stored in GitHub.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only the production environment of this repository (main branch deployments).
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_oidc_subject]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "github-deploy-theodoremayi-site"
  description        = "GitHub Actions deploys ${var.github_repository} to S3 + CloudFront"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# Least privilege: write this bucket, invalidate this distribution, nothing else.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.site.arn]
  }

  statement {
    sid       = "WriteSiteFiles"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${data.aws_s3_bucket.site.arn}/*"]
  }

  statement {
    sid       = "InvalidateCache"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [data.aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy-site"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

output "github_secret_AWS_DEPLOY_ROLE_ARN" {
  description = "Save this value as the AWS_DEPLOY_ROLE_ARN secret of the GitHub repository"
  value       = aws_iam_role.deploy.arn
}
