variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "project_name" {
  type    = string
  default = "run-the-world"
}

variable "frontend_domain" {
  type    = string
  default = ""
}

variable "strava_secret_name" {
  type    = string
  default = "rtw/strava"
}
