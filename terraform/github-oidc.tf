
variable "github_org" {
  type        = string
  description = "The GitHub organization or username owning the repositories"
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Create the AWS IAM OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# IAM Policy Document for OIDC Assume Role
data "aws_iam_policy_document" "gha_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Condition: Validate the audience is sts.amazonaws.com
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Condition: Restrict access to main branch of FifaApp-backend and FifaApp-frontend
    # This naturally excludes PR builds since they run on non-main feature branches.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/FifaApp-backend:ref:refs/heads/main",
        "repo:${var.github_org}/FifaApp-frontend:ref:refs/heads/main"
      ]
    }
  }
}

# 5. Create the IAM Role for GitHub Actions
resource "aws_iam_role" "gha_role" {
  name               = "fifaapp-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.gha_assume_role.json
}

# 6. Attach the Existing ECR Access Policy from Stage 6
resource "aws_iam_role_policy_attachment" "gha_ecr_access" {
  role       = aws_iam_role.gha_role.name
  policy_arn = aws_iam_policy.ecr_access.arn
}

