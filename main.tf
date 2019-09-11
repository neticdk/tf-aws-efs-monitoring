locals {
  tags = {
    Terraform = "true"
  }

  all_tags = merge(var.tags, local.tags)
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/efs-monitoring"
  retention_in_days = 14

  tags = local.all_tags
}

data "aws_iam_policy_document" "assume" {
  statement {
    sid     = "EfsMonitoringAsuumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name        = "efs-monitoring-lambda"
  description = "Used to monitor efs with lambda"

  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = local.all_tags
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "EfsMonitoringLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:*:*:log-group:/aws/lambda/efs-monitoring:*"
    ]
  }

  statement {
    sid    = "EfsMonitoringFS"
    effect = "Allow"
    actions = [
      "elasticfilesystem:Describe*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EfsMonitoringCloudWatch"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
  }
}


resource "aws_iam_policy" "this" {
  name        = "efs-monitoring"
  description = "Allows monitoring of efs filesystems"
  policy      = data.aws_iam_policy_document.this.json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

data "template_file" "this" {
  template = "${file("${path.module}/templates/monitor_efs_filesystems.py.tpl")}"
}

data "archive_file" "this" {
  type        = "zip"
  output_path = "${path.module}/archives/monitor_efs_filesystems.zip"

  source {
    content  = "${data.template_file.this.rendered}"
    filename = "monitor_efs_filesystems.py"
  }
}

resource "aws_lambda_function" "this" {
  filename      = "${path.module}/archives/monitor_efs_filesystems.zip"
  function_name = "efs-monitoring"
  role          = aws_iam_role.this.arn
  handler       = "monitor_efs_filesystems.lambda_handler"

  description = "Sends EFS files system usage data to CloudWatch"

  source_code_hash = data.archive_file.this.output_base64sha256

  runtime = "python3.7"

  tags = local.all_tags
}

resource "aws_cloudwatch_event_rule" "this" {
  name                = "trigger-efs-monitoring"
  schedule_expression = "cron(0/30 * * * ? *)"
  description         = "Triggers the efs-monitoring lambda function"
  is_enabled          = true

  tags = local.all_tags
}

resource "aws_cloudwatch_event_target" "this" {
  rule = aws_cloudwatch_event_rule.this.name
  arn  = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "this" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}
