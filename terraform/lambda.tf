resource "aws_lambda_function" "go_utils_lambda" {
  filename         = data.external.download_github_release.result.filename
  function_name    = var.name
  role             = aws_iam_role.go_utils_lambda_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  source_code_hash = base64sha256(data.external.download_github_release.result.hash)
  timeout          = 5
  architectures    = ["arm64"]
}

resource "aws_lambda_permission" "go_utils_apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.go_utils_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.go_utils_api.execution_arn}/*/*"
}
