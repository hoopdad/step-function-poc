# Quick Start Guide

Get your Step Functions workflow up and running in 5 minutes!

## Prerequisites
- AWS CLI configured
- Terraform >= 1.0
- Node.js >= 18.x

## Deploy in 3 Commands

```bash
# 1. Deploy everything
chmod +x deploy.sh
./deploy.sh

# 2. Start a workflow execution
./start-execution.sh

# 3. Complete the workflow (send Jira callback)
./send-callback.sh PROJ-12345 "Story completed" success
```

That's it! Your workflow is complete.

## What Just Happened?

1. **Infrastructure Created**:
   - Step Functions state machine
   - 4 Lambda functions (callback + 3 mock APIs)
   - S3 bucket with folders
   - DynamoDB table for task tokens
   - API Gateway for callbacks
   - IAM roles and CloudWatch logs

2. **Workflow Executed**:
   - Read input from S3
   - Called 3 mock APIs in parallel
   - Stored task token and waited
   - Received callback from "Jira"
   - Wrote results to S3

3. **View Results**:
```bash
# List executions
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/outputs/

# View specific execution
./view-results.sh <EXECUTION_ID>
```

## Test the Mock APIs

```bash
chmod +x test-lambdas.sh
./test-lambdas.sh
```

## Monitor Executions

**AWS Console**:
```
Services → Step Functions → State machines → stepfunctions-poc-dev-workflow
```

**CLI**:
```bash
aws stepfunctions list-executions \
  --state-machine-arn $(terraform output -raw state_machine_arn)
```

## Cleanup

```bash
# Delete S3 contents
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive

# Destroy infrastructure
terraform destroy
```

## Next Steps

See [README.md](README.md) for:
- Architecture details
- Jira integration setup
- Replacing mock APIs with real services
- IAM roles and permissions
- Troubleshooting guide

## Common Commands

```bash
# Get API tokens (for replacing mocks)
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw secrets_manager_arn | awk -F: '{print $NF}') \
  --query SecretString --output text | jq

# View CloudWatch logs
aws logs tail /aws/vendedlogs/states/stepfunctions-poc-dev-workflow --follow

# Check DynamoDB task tokens
aws dynamodb scan --table-name $(terraform output -raw dynamodb_table_name)
```

## Callback API Endpoint

Your Jira automation should POST to:
```bash
terraform output callback_api_endpoint
```

Example payload:
```json
{
  "jiraStoryId": "PROJ-12345",
  "message": "Story completed",
  "status": "success"
}
```

## Troubleshooting

**Execution stuck?**
- Check DynamoDB for task token: `aws dynamodb get-item --table-name <TABLE> --key '{"jiraStoryId":{"S":"PROJ-12345"}}'`

**Lambda errors?**
- View logs: `aws logs tail /aws/lambda/stepfunctions-poc-dev-callback --follow`

**Permission errors?**
- Verify role: `aws sts get-caller-identity`
- Assume user role: See README.md

---

**Need help?** Check [README.md](README.md) for detailed documentation.
