terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.87.0"
    }
    archive = {
      source = "hashicorp/archive"
      version = "~> 2.7.0"
    }
  }

  required_version = ">= 1.10"
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_lambda_layer_version" "python_telegram_bot" {
  filename = "${path.module}/../layer_content.zip"
  layer_name = "python_telegram_bot_layer"
  description = "Contains Python dependencies."
  compatible_runtimes = [ "python3.11" ]
  source_code_hash = "${filebase64sha256("../layer_content.zip")}"
}

resource "aws_iam_role" "lambda_role" {
  name        = "lambda-ssm-role"
  description = "Allows Lambda functions to assume role to access Systems Manager."

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-ssm-policy"
  description = "Allows Lambda to access the relevant parameters stored in Systems Manager."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameter"
        ],
        "Resource" : "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "kms:Decrypt"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda.py"
  output_path = "${path.module}/../lambda.zip"
}

resource "aws_lambda_function" "lambda" {
  description      = "Function that responds to commands sent to the SimplyGo Bot on Telegram."
  filename         = "${path.module}/../lambda.zip"
  function_name    = "simplygo_handler"
  handler          = "lambda.lambda_handler"
  layers           = [ aws_lambda_layer_version.python_telegram_bot.arn, var.lambda_extension_arn ]
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10
}

resource "aws_ssm_parameter" "bot_token" {
  name = "/simplygo-telegram/bot_token"
  description = "The token used to authenticate the Telegram bot."
  type = "SecureString"
  value = var.bot_token
}

resource "aws_ssm_parameter" "chat_id" {
  name = "/simplygo-telegram/chat_id"
  description = "The unique ID of the chat between the user and the bot."
  type = "SecureString"
  value = var.chat_id
}

resource "aws_ssm_parameter" "simplygo_username" {
  name = "/simplygo-telegram/username"
  description = "The username of the SimplyGo account."
  type = "SecureString"
  value = var.simplygo_username
}

resource "aws_ssm_parameter" "simplygo_password" {
  name = "/simplygo-telegram/password"
  description = "The password of the SimplyGo account."
  type = "SecureString"
  value = var.simplygo_password
}

resource "aws_scheduler_schedule" "daily_cron" {
  name = "get_daily_transactions"
  description = "Invokes simplygo_handler Lambda function daily."
  schedule_expression = "cron(55 23 * * ? *)"
  schedule_expression_timezone = "Asia/Singapore"
  target {
    arn = aws_lambda_function.lambda.arn
    role_arn = aws_iam_role.scheduler_role.arn
    input = jsonencode({
      body = {
        CronScheduleType = "daily"
      }
    })
    retry_policy {
      maximum_retry_attempts = 0
    }
  }
  flexible_time_window {
    mode = "OFF"
  }
}

resource "aws_scheduler_schedule" "monthly_cron" {
  name = "get_monthly_transactions"
  description = "Invokes simplygo_handler Lambda function monthly."
  schedule_expression = "cron(56 23 L * ? *)"
  schedule_expression_timezone = "Asia/Singapore"
  target {
    arn = aws_lambda_function.lambda.arn
    role_arn = aws_iam_role.scheduler_role.arn
    input = jsonencode({
      body = {
        CronScheduleType = "monthly"
      }
    })
    retry_policy {
      maximum_retry_attempts = 0
    }
  }
  flexible_time_window {
    mode = "OFF"
  }
}

resource "aws_iam_role" "scheduler_role" {
  name        = "scheduler-execution-role"
  description = "Allows EventBridge scheduler to assume role to invoke Lambda functions."

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "scheduler.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "scheduler_policy" {
  name        = "lambda-invoke-policy"
  description = "Allow permission to invoke Lambda functions."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "scheduler" {
  role       = aws_iam_role.scheduler_role.name
  policy_arn = aws_iam_policy.scheduler_policy.arn
}

variable "bot_token" {
  type = string
}

variable "chat_id" {
  type = string
}

variable "simplygo_username" {
  type = string
}

variable "simplygo_password" {
  type = string
}

variable "lambda_extension_arn" {
  type = string
}

output "python_telegram_bot_arn" {
  value = aws_lambda_layer_version.python_telegram_bot.arn
}

output "lambda_arn" {
  value = aws_lambda_function.lambda.arn
}