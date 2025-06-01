data "http" "github_latest_release" {
  url = "https://api.github.com/repos/${var.github_repo}/releases/latest"

  request_headers = {
    Accept = "application/vnd.github.v3+json"
  }
}

data "external" "download_github_release" {
  program = ["bash", "-c", <<-EOT
    set -e
    
    mkdir -p ./downloads
    curl -L -o "./downloads/${local.zip_filename}" "${local.download_url}"
    
    # Get file size and calculate hash for verification
    if [ -f "./downloads/${local.zip_filename}" ]; then
      SIZE=$(stat -f%z "./downloads/${local.zip_filename}" 2>/dev/null || stat -c%s "./downloads/${local.zip_filename}" 2>/dev/null || echo "0")
      HASH=$(sha256sum "./downloads/${local.zip_filename}" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "./downloads/${local.zip_filename}" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
      echo "{\"filename\":\"./downloads/${local.zip_filename}\",\"size\":\"$SIZE\",\"hash\":\"$HASH\",\"tag\":\"${local.tag_name}\"}"
    else
      echo "{\"error\":\"Failed to download file\"}"
      exit 1
    fi
EOT
  ]

  # Trigger re-download when the tag changes
  query = {
    download_url = local.download_url
    tag_name     = local.tag_name
    filename     = local.zip_filename
  }
}

resource "aws_lambda_function" "go_utils_lambda" {
  filename         = data.external.download_github_release.result.filename
  function_name    = var.name
  role             = aws_iam_role.go_utils_lambda_role.arn
  handler          = "index.handler"
  runtime          = "provided.al2023"
  source_code_hash = base64sha256(data.external.download_github_release.result.hash)
  timeout          = 5
}

resource "aws_api_gateway_integration" "go_utils_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.go_utils_api.id
  resource_id             = aws_api_gateway_resource.go_utils.id
  http_method             = aws_api_gateway_method.go_utils_proxy.http_method
  integration_http_method = "GET"
  type                    = "AWS"
  uri                     = aws_lambda_function.go_utils_lambda.invoke_arn
}

resource "aws_lambda_permission" "go_utils_apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.go_utils_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.go_utils_api.execution_arn}/*/*/*"
}