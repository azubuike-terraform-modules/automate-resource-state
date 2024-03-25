resource "aws_cloudwatch_event_rule" "terminate_rds" {
  name                = "terminate-database-cluster"
  description         = "Terminate database when its past official work hours UTC time"
  schedule_expression = var.cron_value
}

resource "aws_cloudwatch_event_target" "rds_state_lambda_event_target" {
  target_id = aws_lambda_function.rds_state_lambda.id
  rule      = aws_cloudwatch_event_rule.terminate_rds.name
  arn       = aws_lambda_function.rds_state_lambda.arn

}

data "aws_iam_policy_document" "rds_state_lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "rds_state_lambda_role" {
  name               = "RDSExecuteStateRole"
  assume_role_policy = data.aws_iam_policy_document.rds_state_lambda_assume_role.json
}
resource "aws_iam_role_policy" "rds_state_lambda_policy" {
  name = "rds_state_lambda_policy"
  role = aws_iam_role.rds_state_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds:DescribeDBClusterParameters",
          "rds:DeleteDBCluster",
          "rds:DeleteDBInstance",
          "rds:DescribeDBEngineVersions",
          "rds:DescribeGlobalClusters",
          "rds:DescribePendingMaintenanceActions",
          "rds:DescribeDBLogFiles",
          "rds:StopDBInstance",
          "rds:StartDBInstance",
          "rds:DescribeReservedDBInstancesOfferings",
          "rds:DescribeReservedDBInstances",
          "rds:ListTagsForResource",
          "rds:DescribeValidDBInstanceModifications",
          "rds:DescribeDBInstances",
          "rds:DescribeSourceRegions",
          "rds:DescribeDBClusterEndpoints",
          "rds:DescribeDBClusters",
          "rds:DescribeDBClusterParameterGroups",
          "rds:DescribeOptionGroups"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_state_lambda_basic_execution_role" {
  role       = aws_iam_role.rds_state_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "./scripts/db_automate.py"
  output_path = "lambda_db_automate.zip"
}

resource "aws_lambda_function" "rds_state_lambda" {
  filename         = "lambda_db_automate.zip"
  function_name    = "rds_state_lambda"
  role             = aws_iam_role.rds_state_lambda_role.arn
  handler          = "db_automate.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.8"

  environment {
    variables = {
      REGION = var.region
      KEY    = var.tag_key
      VALUE  = var.tag_value
    }

  }

}

resource "aws_lambda_permission" "with_event_bridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_state_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.terminate_rds.arn
}