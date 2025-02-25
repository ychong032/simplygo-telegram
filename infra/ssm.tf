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