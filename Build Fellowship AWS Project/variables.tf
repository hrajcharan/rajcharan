variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "gogreen"
}

variable "db_username" {
  type    = string
  default = "dbadmin"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "ChangeMeStrong123!"
}

variable "alert_emails" {
  type    = list(string)
  default = []
}

variable "my_ip" {
  type    = string
  default = "" # if empty, auto-detect
}
