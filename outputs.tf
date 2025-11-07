output "s3_bucket_name" {
  description = "Name of the S3 bucket for workflow data"
  value       = aws_s3_bucket.workflow_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.workflow_bucket.arn
}

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.workflow.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.workflow.name
}

output "callback_api_endpoint" {
  description = "API Gateway endpoint URL for Jira callback"
  value       = "${aws_apigatewayv2_api.callback_api.api_endpoint}/callback"
}

output "callback_lambda_arn" {
  description = "ARN of the callback Lambda function"
  value       = aws_lambda_function.callback.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for task token mapping"
  value       = aws_dynamodb_table.task_token_mapping.name
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret containing API tokens"
  value       = aws_secretsmanager_secret.mock_api_tokens.arn
}

output "stepfunctions_execution_role_arn" {
  description = "ARN of the Step Functions execution role"
  value       = aws_iam_role.stepfunctions_execution_role.arn
}

output "stepfunctions_user_role_arn" {
  description = "ARN of the role for users to execute and view Step Functions"
  value       = aws_iam_role.stepfunctions_user_role.arn
}

output "mock_validation_lambda_arn" {
  description = "ARN of the mock validation API Lambda"
  value       = aws_lambda_function.mock_api_validation.arn
}

output "mock_deployment_lambda_arn" {
  description = "ARN of the mock deployment API Lambda"
  value       = aws_lambda_function.mock_api_deployment.arn
}

output "mock_notification_lambda_arn" {
  description = "ARN of the mock notification API Lambda"
  value       = aws_lambda_function.mock_api_notification.arn
}

output "api_tokens" {
  description = "Instructions to retrieve API tokens"
  value       = "Run: aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mock_api_tokens.name} --query SecretString --output text | jq"
  sensitive   = false
}

output "example_execution_command" {
  description = "Example command to start an execution"
  value       = "aws stepfunctions start-execution --state-machine-arn ${aws_sfn_state_machine.workflow.arn} --input file://example-input.json"
}
