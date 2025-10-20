# CI assume role (for CodeBuild/CodePipeline / GitHub Actions to assume)
data "aws_iam_policy_document" "ci_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com", "codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ci_role" {
  name               = "${var.project_prefix}-ci-role"
  assume_role_policy = data.aws_iam_policy_document.ci_assume.json
  tags = { Name = "${var.project_prefix}-ci-role" }
}

# (Learning/demo) Attach AdministratorAccess for CI role — tighten later
resource "aws_iam_role_policy_attachment" "ci_admin_attach" {
  role       = aws_iam_role.ci_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Lambda execution role (basic)
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "${var.project_prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags = { Name = "${var.project_prefix}-lambda-exec" }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
