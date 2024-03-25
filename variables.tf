variable "region" {
  type    = string
  default = "us-east-1"
}
variable "cron_value" {
  type    = string
  default = "cron(45 23 * * ? *)"
}
variable "tag_key" {
  type    = string
  default = "Group"
}
variable "tag_value" {
  type    = string
  default = "scheduled shutdown"
}