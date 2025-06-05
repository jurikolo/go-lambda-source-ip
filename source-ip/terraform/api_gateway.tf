resource "aws_api_gateway_rest_api" "go_utils_api" {
  name = var.name
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "*"
      }
    ]
  })
}

resource "aws_api_gateway_resource" "go_utils" {
  rest_api_id = aws_api_gateway_rest_api.go_utils_api.id
  parent_id   = aws_api_gateway_rest_api.go_utils_api.root_resource_id
  path_part   = var.api_gateway_path_part
}

resource "aws_api_gateway_method" "go_utils_proxy" {
  rest_api_id   = aws_api_gateway_rest_api.go_utils_api.id
  resource_id   = aws_api_gateway_resource.go_utils.id
  http_method   = var.api_gateway_http_method
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "go_utils_proxy" {
  rest_api_id = aws_api_gateway_rest_api.go_utils_api.id
  resource_id = aws_api_gateway_resource.go_utils.id
  http_method = aws_api_gateway_method.go_utils_proxy.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration" "go_utils_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.go_utils_api.id
  resource_id             = aws_api_gateway_resource.go_utils.id
  http_method             = aws_api_gateway_method.go_utils_proxy.http_method
  integration_http_method = "POST" // Lambda only accepts POST HTTP method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.go_utils_lambda.invoke_arn
  passthrough_behavior    = "WHEN_NO_TEMPLATES"
}

# resource "aws_api_gateway_integration_response" "go_utils_proxy" {
#   rest_api_id = aws_api_gateway_rest_api.go_utils_api.id
#   resource_id = aws_api_gateway_resource.go_utils.id
#   http_method = aws_api_gateway_method.go_utils_proxy.http_method
#   status_code = aws_api_gateway_method_response.go_utils_proxy.status_code

#   response_templates = {
#     "application/json" = "$input.body"
#   }

#   depends_on = [
#     aws_api_gateway_method.go_utils_proxy,
#     aws_api_gateway_integration.go_utils_lambda_integration
#   ]
# }

resource "aws_api_gateway_deployment" "go_utils_deployment" {
  depends_on = [
    aws_api_gateway_integration.go_utils_lambda_integration,
  ]
  rest_api_id = aws_api_gateway_rest_api.go_utils_api.id
}

resource "aws_api_gateway_stage" "go_utils_stage" {
  deployment_id = aws_api_gateway_deployment.go_utils_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.go_utils_api.id
  stage_name    = "prod"
}

# Error handling
# resource "aws_api_gateway_method_response" "go_utils_proxy_error" {
#   rest_api_id = aws_api_gateway_rest_api.go_utils_api.id
#   resource_id = aws_api_gateway_resource.go_utils.id
#   http_method = aws_api_gateway_method.go_utils_proxy.http_method
#   status_code = "500"

#   response_models = {
#     "application/json" = "Error"
#   }
# }

# resource "aws_api_gateway_integration_response" "go_utils_proxy_error" {
#   rest_api_id = aws_api_gateway_rest_api.go_utils_api.id
#   resource_id = aws_api_gateway_resource.go_utils.id
#   http_method = aws_api_gateway_method.go_utils_proxy.http_method
#   status_code = "500"

#   selection_pattern = ".*error.*"

#   response_templates = {
#     "application/json" = jsonencode({
#       "error" = "Internal Server Error",
#       "message" = "$input.path('$.errorMessage')"
#     })
#   }

#   depends_on = [
#     aws_api_gateway_method.go_utils_proxy,
#     aws_api_gateway_integration.go_utils_lambda_integration
#   ]
# }
