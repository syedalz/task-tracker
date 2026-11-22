# Tell AWS to trust GitHub as an identity provider
resource "aws_iam_openid_connect_provider" "github" {

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

}

resource "aws_iam_role" "github_deploy" {

  name = "task-tracker-github-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:syedalz@195389451/task-tracker@1423978832:ref:refs/heads/main"
        }
      }
    }]
  })

}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "github_deploy" {
  name = "task-tracker-github-deploy-permissions"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SendCommandToAppInstance"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ec2:us-east-2:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = {
          StringEquals = {
            "ssm:resourceTag/Name" = "task-tracker-dev-app"
          }
        }
      },
      {
        Sid      = "UseRunShellScriptDocument"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ssm:us-east-2::document/AWS-RunShellScript"
      },
      {
        Sid      = "CheckCommandResult"
        Effect   = "Allow"
        Action   = "ssm:GetCommandInvocation"
        Resource = "*"
      },
      {
        Sid      = "FindInstanceByTag"
        Effect   = "Allow"
        Action   = "ec2:DescribeInstances"
        Resource = "*"
      }
    ]
  })
}
