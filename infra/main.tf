resource "aws_iam_role" "lambda_role" {
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

resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda-politica"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# -------- Lambda Function --------

resource "aws_lambda_function" "lambda_function" {
  function_name = "lanchonete-login-lambda-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  source_code_hash = filebase64sha256("../lambda/lambda.zip")
  filename         = "../lambda/lambda.zip"
}

# -------- API Gateway HTTP API --------


resource "aws_api_gateway_rest_api" "rest_api" {
  name        = "lanchonete-loginlambda-rest-api"
  description = "API Gateway REST para login sistema lanchonete"
}

resource "aws_api_gateway_resource" "rest_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "cpf"
}


resource "aws_api_gateway_request_validator" "query_validator" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  name        = "ValidateQueryStringAndHeaders"

  validate_request_parameters = true
  validate_request_body       = false
}

resource "aws_api_gateway_method" "rest_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.rest_resource.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.cpf" = true
  }

  request_validator_id = aws_api_gateway_request_validator.query_validator.id
}

resource "aws_api_gateway_integration" "rest_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.rest_resource.id
  http_method             = aws_api_gateway_method.rest_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn

  request_parameters = {
    "integration.request.querystring.cpf" = "method.request.querystring.cpf"
  }
}

resource "aws_api_gateway_deployment" "rest_deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  depends_on  = [aws_api_gateway_integration.rest_integration]
}

resource "aws_api_gateway_stage" "rest_stage" {
  deployment_id = aws_api_gateway_deployment.rest_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "default"
}

output "api_gateway_url" {
  value = "${aws_api_gateway_rest_api.rest_api.execution_arn}/default/cpf"
}