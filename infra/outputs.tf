output "python_telegram_bot_arn" {
  value = aws_lambda_layer_version.python_telegram_bot.arn
}

output "lambda_arn" {
  value = aws_lambda_function.lambda.arn
}