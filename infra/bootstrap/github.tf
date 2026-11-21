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
