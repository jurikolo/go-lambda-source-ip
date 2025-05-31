resource "aws_api_gateway_rest_api" "go_utils_api" {
  name        = "go-utils"
  description = "Go utils"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "source_ip" {
  rest_api_id = aws_api_gateway_rest_api.go_utils_api.id
  parent_id   = aws_api_gateway_rest_api.go_utils_api.root_resource_id
  path_part   = "/"
}

resource "aws_api_gateway_method" "source_ip_proxy" {
  rest_api_id   = aws_api_gateway_rest_api.go_utils_api.id
  resource_id   = aws_api_gateway_resource.source_ip.id
  http_method   = "GET"
  authorization = "NONE"
}

# resource "aws_api_gateway_integration" "source_ip_lambda_integration" {
#   rest_api_id             = aws_api_gateway_rest_api.go_utils_api.id
#   resource_id             = aws_api_gateway_resource.source_ip.id
#   http_method             = aws_api_gateway_method.source_ip_proxy.http_method
#   integration_http_method = "GET"
#   type                    = "MOCK"
# }

resource "aws_api_gateway_method_response" "source_ip_proxy" {
  rest_api_id = aws_api_gateway_rest_api.go_utils_api.id
  resource_id = aws_api_gateway_resource.source_ip.id
  http_method = aws_api_gateway_method.source_ip_proxy.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "source_ip_proxy" {
  rest_api_id = aws_api_gateway_rest_api.go_utils_api.id
  resource_id = aws_api_gateway_resource.source_ip.id
  http_method = aws_api_gateway_method.source_ip_proxy.http_method
  status_code = aws_api_gateway_method_response.source_ip_proxy.status_code
  depends_on = [
    aws_api_gateway_method.source_ip_proxy,
    aws_api_gateway_integration.source_ip_lambda_integration
  ]
}

resource "aws_api_gateway_deployment" "source_ip_deployment" {
  depends_on = [
    aws_api_gateway_integration.source_ip_lambda_integration,
  ]
  rest_api_id = aws_api_gateway_rest_api.go_utils_api.id
}

data "http" "github_latest_release" {
  url = "https://api.github.com/repos/${var.github_repo}/releases/latest"

  request_headers = {
    Accept = "application/vnd.github.v3+json"
  }
}

resource "null_resource" "download_github_release" {
  triggers = {
    tag_name = local.tag_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ./downloads
      curl -L -o "./downloads/${local.zip_filename}" "${local.download_url}"
    EOT
  }
}

resource "aws_lambda_function" "source_ip_lambda" {
  filename         = "./downloads/${local.zip_filename}"
  function_name    = "myLambdaFunction"
  role             = aws_iam_role.source_ip_lambda_role.arn
  handler          = "index.handler"
  runtime          = "al2023"
  source_code_hash = filebase64sha256("./downloads/${local.zip_filename}")
  timeout          = 5
}

resource "aws_iam_role" "source_ip_lambda_role" {
  name = "lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_api_gateway_integration" "source_ip_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.go_utils_api.id
  resource_id             = aws_api_gateway_resource.source_ip.id
  http_method             = aws_api_gateway_method.source_ip_proxy.http_method
  integration_http_method = "GET"
  type                    = "AWS"
  uri                     = aws_lambda_function.source_ip_lambda.invoke_arn
}

resource "aws_iam_role_policy_attachment" "source_ip_lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.source_ip_lambda_role.name
}

resource "aws_lambda_permission" "source_ip_apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.source_ip_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.go_utils_api.execution_arn}/*/*/*"
}