variable "region" {
  type    = string
  default = "us-east-1"
}

variable "use_floci" {
  description = "true: деплой у floci (Docker), false: у справжній AWS"
  type        = bool
  default     = true
}

variable "floci_endpoint" {
  type    = string
  default = "http://localhost:4566"
}

variable "project" {
  type    = string
  default = "kimachuk-books"
}

variable "stage_name" {
  type    = string
  default = "dev"
}
