variable "aws_access_key_id" {
  type = string
}

variable "aws_secret_key_id" {
  type = string
}

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
}

variable "name" {
  description = "Common name for resources"
  type        = string
}

variable "api_gateway_path_part" {
  description = "API Gateway path part"
  type        = string
}

variable "api_gateway_http_method" {
  description = "API Gateway HTTP method"
  type        = string
}
