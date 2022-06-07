provider "aws" {
    region = "us-east-1"
}

variable "profile" {
     default = "dev-01"
}

resource "null_resource" "compile" {
    triggers = {
        build_number = timestamp()
    }
    provisioner "local-exec" {
        command = "go build -o build/main go_lambda/main.go"
    }
}

data "archive_file" "go_lambda_zip"{
    type = "zip"
    source_dir = "build"
    output_path = "output/main.zip"
}

resource "aws_iam_role" "go_lambda_role" {
    name = "go_lambda_role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid    = ""
            Principal = {
            Service = "lambda.amazonaws.com"
            }
        },
        ]
    })
}

resource "aws_lambda_function" "go_lambda" {
    filename      = data.archive_file.go_lambda_zip.output_path
    function_name = "handler"
    role          = "${aws_iam_role.go_lambda_role.arn}"
    handler       = "main.handler"

    source_code_hash = data.archive_file.go_lambda_zip.output_base64sha256//"${filebase64sha256("output/main.zip")}"

    runtime = "go1.x"
}

resource "aws_lambda_permission" "apigw_lambda" {
    statement_id  = "AllowAPIgatewayInvokation"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.go_lambda.function_name
    principal     = "apigateway.amazonaws.com"

    //source_arn = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_rest_api" "api-gateway" {
    name = "api-gateway"
    endpoint_configuration {
        types = ["REGIONAL"]
    }
}

resource "aws_api_gateway_resource" "person" {
    rest_api_id = aws_api_gateway_rest_api.api-gateway.id
    parent_id   = aws_api_gateway_rest_api.api-gateway.root_resource_id
    path_part   = "person"
}

// GET
resource "aws_api_gateway_method" "get" {
    rest_api_id       = aws_api_gateway_rest_api.api-gateway.id
    resource_id       = aws_api_gateway_resource.person.id
    http_method       = "GET"
    authorization     = "NONE"
    api_key_required  = false
}

resource "aws_api_gateway_integration" "integration" {
    rest_api_id             = aws_api_gateway_rest_api.api-gateway.id
    resource_id             = aws_api_gateway_resource.person.id
    http_method             = aws_api_gateway_method.get.http_method
    integration_http_method = "POST"
    type                    = "AWS_PROXY"
    uri                     = aws_lambda_function.go_lambda.invoke_arn
}


resource "aws_api_gateway_deployment" "deployment1" {
  rest_api_id = aws_api_gateway_rest_api.api-gateway.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api-gateway.body))
  }

  depends_on = [aws_api_gateway_integration.integration]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.deployment1.id
  rest_api_id   = aws_api_gateway_rest_api.api-gateway.id
  stage_name    = var.profile
}

output "complete_unvoke_url"   {value = "${aws_api_gateway_deployment.deployment1.invoke_url}${aws_api_gateway_stage.example.stage_name}/${aws_api_gateway_resource.person.path_part}"}

/*
resource "aws_apigatewayv2_api" "lambda_api"{
    name = "http-api"
    protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda_stage"{
    api_id = aws_apigatewayv2_api.lambda_api.id
    name = "$default"
    auto_deploy = true
}

resource "aws_apigatewayv2_route" "lambda_route"{
    api_id = aws_apigatewayv2_api.lambda_api.id
    route_key = "GET /{proxy+}"
    target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}
*/

