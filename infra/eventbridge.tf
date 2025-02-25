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