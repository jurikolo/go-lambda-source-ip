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