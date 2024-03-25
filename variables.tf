variable "region" {
  type    = string
  default = "us-east-1"
}
variable "cron_value" {
  type    = string
  default = "cron(40 10 * * ? *)"
}
variable "tag_key" {
  type    = string
  default = "group"
}
variable "tag_value" {
  type    = string
  default = "scheduled shutdown"
}
