resource "aws_lambda_layer_version" "python_telegram_bot" {
  filename = "${path.module}/../layer_content.zip"
  layer_name = "python_telegram_bot_layer"
  description = "Contains Python dependencies."
  compatible_runtimes = [ "python3.11" ]
  source_code_hash = "${filebase64sha256("../layer_content.zip")}"
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