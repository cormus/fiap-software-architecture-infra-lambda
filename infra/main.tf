# Criar uma IAM Role noque concede permissões específicas a uma função Lambda 
# permitindo que ela seja executada com os privilégios necessários

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

# Anexar a política IAM existente a  role IAM que foi criada
# garantindo que a função Lambda tenha as permissões necessárias para executar

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

#Cria o API Gateway REST API que servirá como ponto de entrada para a função Lambda

resource "aws_api_gateway_rest_api" "rest_api" {
  name        = "lanchonete-loginlambda-rest-api"
  description = "API Gateway REST para login sistema lanchonete"
}

# Cria um recurso dentro do API Gateway do tipo REST API
# cujo caminho será "/cpf"

resource "aws_api_gateway_resource" "rest_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "cpf"
}

# Cria um validador de requisições para o API Gateway
# que valida os parâmetros de consulta e cabeçalhos da requisição mas não valida o corpo da requisição

resource "aws_api_gateway_request_validator" "query_validator" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  name        = "ValidateQueryStringAndHeaders"

  validate_request_parameters = true
  validate_request_body       = false
}

# Cria um método HTTP GET no recurso "/cpf" do API Gateway
# que espera um parâmetro de consulta chamado "cpf"
# aplica a validator de requisições criado anteriormente

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

# Cria uma integração entre o método HTTP GET do API Gateway e a função Lambda
# parametros de requisição são mapeados para a função Lambda

resource "aws_api_gateway_integration" "rest_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.rest_resource.id
  http_method             = aws_api_gateway_method.rest_method.http_method
  integration_http_method = "POST" #invoca a função Lambda usando o método POST
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn # define qual função Lambda que será invocada

  # Define os parâmetros de requisição que serão passados para a função Lambda
  request_parameters = {
    "integration.request.querystring.cpf" = "method.request.querystring.cpf"
  }

  # Define o mapeamento do corpo da requisição para a função Lambda
  request_templates = {
    "application/json" = "{\"cpf\": $input.params(\"cpf\")}"
  }
    
}

# Cria um deployment do API Gateway REST API
# que aplica as configurações do API Gateway e cria um ponto de acesso para a função Lambda

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

# Permissão para a API Gateway invocar a função Lambda
# Sem essa permissão a API Gateway não consegue chamar a função Lambda

resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}