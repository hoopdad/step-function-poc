terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for inputs, outputs, and logs
resource "aws_s3_bucket" "workflow_bucket" {
  bucket = "${var.project_name}-${var.environment}-workflow-${data.aws_caller_identity.current.account_id}"
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-workflow-bucket"
  })
}

resource "aws_s3_bucket_versioning" "workflow_bucket_versioning" {
  bucket = aws_s3_bucket.workflow_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "workflow_bucket_encryption" {
  bucket = aws_s3_bucket.workflow_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create folder structure in S3
resource "aws_s3_object" "inputs_folder" {
  bucket = aws_s3_bucket.workflow_bucket.id
  key    = "inputs/"
  content = ""
}

resource "aws_s3_object" "outputs_folder" {
  bucket = aws_s3_bucket.workflow_bucket.id
  key    = "outputs/"
  content = ""
}

resource "aws_s3_object" "logs_folder" {
  bucket = aws_s3_bucket.workflow_bucket.id
  key    = "logs/"
  content = ""
}

# DynamoDB Table for Task Token Mapping
resource "aws_dynamodb_table" "task_token_mapping" {
  name           = "${var.project_name}-${var.environment}-task-tokens"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "jiraStoryId"

  attribute {
    name = "jiraStoryId"
    type = "S"
  }

  ttl {
    attribute_name = "expirationTime"
    enabled        = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-task-tokens"
  })
}

# Secrets Manager for Mock API Tokens
resource "aws_secretsmanager_secret" "mock_api_tokens" {
  name = "${var.project_name}-${var.environment}-mock-api-tokens"
  description = "Bearer tokens for mock external APIs"
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "mock_api_tokens_value" {
  secret_id = aws_secretsmanager_secret.mock_api_tokens.id
  secret_string = jsonencode({
    validationApiToken   = "mock-validation-token-${random_string.api_token_suffix.result}"
    deploymentApiToken   = "mock-deployment-token-${random_string.api_token_suffix.result}"
    notificationApiToken = "mock-notification-token-${random_string.api_token_suffix.result}"
  })
}

resource "random_string" "api_token_suffix" {
  length  = 32
  special = false
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "stepfunctions_log_group" {
  name              = "/aws/vendedlogs/states/${var.project_name}-${var.environment}-workflow"
  retention_in_days = 7
  
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_callback_log_group" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-callback"
  retention_in_days = 7
  
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_mock_validation_log_group" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-mock-validation"
  retention_in_days = 7
  
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_mock_deployment_log_group" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-mock-deployment"
  retention_in_days = 7
  
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_mock_notification_log_group" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-mock-notification"
  retention_in_days = 7
  
  tags = var.tags
}

# Lambda Functions - Mock APIs
# Package Lambda code
data "archive_file" "mock_api_validation" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/mock-api-validation"
  output_path = "${path.module}/builds/mock-api-validation.zip"
}

data "archive_file" "mock_api_deployment" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/mock-api-deployment"
  output_path = "${path.module}/builds/mock-api-deployment.zip"
}

data "archive_file" "mock_api_notification" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/mock-api-notification"
  output_path = "${path.module}/builds/mock-api-notification.zip"
}

data "archive_file" "callback_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/callback"
  output_path = "${path.module}/builds/callback.zip"
}

data "archive_file" "store_task_token_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/store-task-token"
  output_path = "${path.module}/builds/store-task-token.zip"
}

data "archive_file" "write_outputs_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/write-outputs"
  output_path = "${path.module}/builds/write-outputs.zip"
}

# Mock Validation API Lambda
resource "aws_lambda_function" "mock_api_validation" {
  filename         = data.archive_file.mock_api_validation.output_path
  function_name    = "${var.project_name}-${var.environment}-mock-validation"
  role            = aws_iam_role.lambda_mock_api_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.mock_api_validation.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = 30

  environment {
    variables = {
      SECRET_NAME = aws_secretsmanager_secret.mock_api_tokens.name
      TOKEN_KEY   = "validationApiToken"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mock-validation"
  })
}

# Mock Deployment API Lambda
resource "aws_lambda_function" "mock_api_deployment" {
  filename         = data.archive_file.mock_api_deployment.output_path
  function_name    = "${var.project_name}-${var.environment}-mock-deployment"
  role            = aws_iam_role.lambda_mock_api_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.mock_api_deployment.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = 60

  environment {
    variables = {
      SECRET_NAME = aws_secretsmanager_secret.mock_api_tokens.name
      TOKEN_KEY   = "deploymentApiToken"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mock-deployment"
  })
}

# Mock Notification API Lambda
resource "aws_lambda_function" "mock_api_notification" {
  filename         = data.archive_file.mock_api_notification.output_path
  function_name    = "${var.project_name}-${var.environment}-mock-notification"
  role            = aws_iam_role.lambda_mock_api_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.mock_api_notification.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = 30

  environment {
    variables = {
      SECRET_NAME = aws_secretsmanager_secret.mock_api_tokens.name
      TOKEN_KEY   = "notificationApiToken"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mock-notification"
  })
}

# Callback Lambda
resource "aws_lambda_function" "callback" {
  filename         = data.archive_file.callback_lambda.output_path
  function_name    = "${var.project_name}-${var.environment}-callback"
  role            = aws_iam_role.lambda_callback_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.callback_lambda.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = 30

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.task_token_mapping.name
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-callback"
  })
}

# Store Task Token Lambda
resource "aws_lambda_function" "store_task_token" {
  filename         = data.archive_file.store_task_token_lambda.output_path
  function_name    = "${var.project_name}-${var.environment}-store-task-token"
  role            = aws_iam_role.lambda_mock_api_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.store_task_token_lambda.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = 300

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.task_token_mapping.name
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-store-task-token"
  })
}

# Write Outputs Lambda
resource "aws_lambda_function" "write_outputs" {
  filename         = data.archive_file.write_outputs_lambda.output_path
  function_name    = "${var.project_name}-${var.environment}-write-outputs"
  role            = aws_iam_role.lambda_mock_api_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.write_outputs_lambda.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = 30

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.workflow_bucket.id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-write-outputs"
  })
}

# API Gateway for Callback Lambda
resource "aws_apigatewayv2_api" "callback_api" {
  name          = "${var.project_name}-${var.environment}-callback-api"
  protocol_type = "HTTP"
  description   = "API Gateway for Jira callback to Step Functions"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }

  tags = var.tags
}

resource "aws_apigatewayv2_stage" "callback_api_stage" {
  api_id      = aws_apigatewayv2_api.callback_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}-callback"
  retention_in_days = 7
  
  tags = var.tags
}

resource "aws_apigatewayv2_integration" "callback_integration" {
  api_id           = aws_apigatewayv2_api.callback_api.id
  integration_type = "AWS_PROXY"

  integration_method = "POST"
  integration_uri    = aws_lambda_function.callback.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "callback_route" {
  api_id    = aws_apigatewayv2_api.callback_api.id
  route_key = "POST /callback"
  target    = "integrations/${aws_apigatewayv2_integration.callback_integration.id}"
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.callback.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.callback_api.execution_arn}/*/*"
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "workflow" {
  name     = "${var.project_name}-${var.environment}-workflow"
  role_arn = aws_iam_role.stepfunctions_execution_role.arn

  definition = templatefile("${path.module}/state-machine.json", {
    workflow_bucket                  = aws_s3_bucket.workflow_bucket.id
    dynamodb_table                   = aws_dynamodb_table.task_token_mapping.name
    mock_validation_lambda_arn       = aws_lambda_function.mock_api_validation.arn
    mock_deployment_lambda_arn       = aws_lambda_function.mock_api_deployment.arn
    mock_notification_lambda_arn     = aws_lambda_function.mock_api_notification.arn
    store_task_token_lambda_arn      = aws_lambda_function.store_task_token.arn
    write_outputs_lambda_arn         = aws_lambda_function.write_outputs.arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.stepfunctions_log_group.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = var.tags
}
