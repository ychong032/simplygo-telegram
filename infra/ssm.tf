resource "aws_ssm_parameter" "bot_token" {
  name = "/simplygo-telegram/bot_token"
  description = "The token used to authenticate the Telegram bot."
  type = "SecureString"
  value = var.bot_token
}

resource "aws_ssm_parameter" "credential_set" {
  for_each = toset(var.credentials)

  name = "/simplygo-telegram/user${index(var.credentials, each.value)}"
  type = "SecureString"
  value = each.value
}