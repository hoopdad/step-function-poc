# AWS Step Functions POC with Jira Integration

This project demonstrates an AWS Step Functions workflow that:
1. Reads input from S3 (Jira story ID and package IDs)
2. Calls multiple mock APIs in parallel (with bearer token authentication)
3. Stores a task token in DynamoDB
4. Waits for a callback from Jira via API Gateway
5. Writes results and logs to S3

## Architecture

```
┌─────────────┐
│   S3 Bucket │
│  (inputs/)  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│     Step Functions State Machine        │
│  ┌─────────────────────────────────┐   │
│  │  1. Read Input from S3          │   │
│  └────────────┬────────────────────┘   │
│               │                         │
│  ┌────────────▼────────────────────┐   │
│  │  2. Parallel API Calls:         │   │
│  │     - Validation API            │   │
│  │     - Deployment API            │   │
│  │     - Notification API          │   │
│  └────────────┬────────────────────┘   │
│               │                         │
│  ┌────────────▼────────────────────┐   │
│  │  3. Store Task Token (DynamoDB) │   │
│  │     [PAUSED - Wait for Jira]    │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
                │
                │ (callback when Jira story = Done)
                │
┌───────────────▼──────────────┐
│  Jira Automation Webhook     │
└───────────────┬──────────────┘
                │
        ┌───────▼────────┐
        │  API Gateway   │
        └───────┬────────┘
                │
        ┌───────▼────────┐
        │ Callback Lambda│
        └───────┬────────┘
                │
                ▼
    [Resume Step Functions]
                │
                ▼
       ┌────────────────┐
       │  Write Results │
       │  to S3         │
       └────────────────┘
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Node.js >= 18.x (for local Lambda development)
- jq (for parsing JSON in bash scripts)

## Directory Structure

```
step-functions-poc/
├── main.tf                          # Main Terraform configuration
├── variables.tf                     # Terraform variables
├── outputs.tf                       # Terraform outputs
├── iam.tf                          # IAM roles and policies
├── state-machine.json              # Step Functions ASL definition
├── example-input.json              # Example execution input
├── workflow-input.json             # Example S3 workflow input
├── lambda/
│   ├── callback/
│   │   ├── index.js               # Jira callback handler
│   │   └── package.json
│   ├── mock-api-validation/
│   │   ├── index.js               # Mock validation API
│   │   └── package.json
│   ├── mock-api-deployment/
│   │   ├── index.js               # Mock deployment API
│   │   └── package.json
│   └── mock-api-notification/
│       ├── index.js               # Mock notification API
│       └── package.json
└── README.md                       # This file
```

## Deployment

### Step 1: Install Lambda Dependencies

```bash
cd lambda/callback && npm install && cd ../..
cd lambda/mock-api-validation && npm install && cd ../..
cd lambda/mock-api-deployment && npm install && cd ../..
cd lambda/mock-api-notification && npm install && cd ../..
```

### Step 2: Deploy Infrastructure with Terraform

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

This will create:
- Step Functions state machine
- S3 bucket with folders (inputs/, outputs/, logs/)
- 4 Lambda functions (callback + 3 mock APIs)
- DynamoDB table for task token mapping
- API Gateway for Jira callback
- IAM roles and policies
- CloudWatch log groups
- Secrets Manager secret with mock API tokens

### Step 3: Note Important Outputs

After deployment, Terraform will output:

```bash
# Get the API endpoint for Jira
terraform output callback_api_endpoint

# Get the S3 bucket name
terraform output s3_bucket_name

# Get the state machine ARN
terraform output state_machine_arn

# Get API tokens (for reference when replacing mock APIs)
terraform output api_tokens
```

## Usage

### 1. Upload Input File to S3

```bash
# Get bucket name
BUCKET_NAME=$(terraform output -raw s3_bucket_name)

# Upload the workflow input
aws s3 cp workflow-input.json s3://$BUCKET_NAME/inputs/workflow-input.json
```

### 2. Start Step Functions Execution

```bash
# Get state machine ARN
STATE_MACHINE_ARN=$(terraform output -raw state_machine_arn)

# Start execution
aws stepfunctions start-execution \
  --state-machine-arn $STATE_MACHINE_ARN \
  --input file://example-input.json \
  --name "test-execution-$(date +%s)"
```

### 3. Monitor Execution

Via AWS Console:
- Go to Step Functions console
- Click on the state machine
- View the execution graph and logs

Via CLI:
```bash
# List executions
aws stepfunctions list-executions \
  --state-machine-arn $STATE_MACHINE_ARN

# Describe specific execution
aws stepfunctions describe-execution \
  --execution-arn <EXECUTION_ARN>
```

### 4. Simulate Jira Callback

The workflow will pause at "Wait for Jira" step. To complete it:

```bash
# Get the callback API endpoint
CALLBACK_URL=$(terraform output -raw callback_api_endpoint)

# Send callback (success)
curl -X POST $CALLBACK_URL \
  -H "Content-Type: application/json" \
  -d '{
    "jiraStoryId": "PROJ-12345",
    "message": "Jira story marked as Done",
    "status": "success"
  }'

# Or send callback (failure)
curl -X POST $CALLBACK_URL \
  -H "Content-Type: application/json" \
  -d '{
    "jiraStoryId": "PROJ-12345",
    "message": "Jira story failed validation",
    "status": "failure"
  }'
```

### 5. View Results

```bash
# List outputs
aws s3 ls s3://$BUCKET_NAME/outputs/ --recursive

# Download result
aws s3 cp s3://$BUCKET_NAME/outputs/<EXECUTION_ID>/result.json .

# View logs
aws s3 cp s3://$BUCKET_NAME/logs/<EXECUTION_ID>/execution.log -
```

## IAM Roles

### 1. Step Functions Execution Role
- Invokes Lambda functions
- Reads/writes to S3
- Reads from Secrets Manager
- Writes to DynamoDB
- Writes CloudWatch logs

### 2. Lambda Execution Roles
- **Mock API Role**: Reads Secrets Manager, writes CloudWatch logs
- **Callback Role**: Calls Step Functions API (SendTaskSuccess/Failure), reads/writes DynamoDB

### 3. User Role (for running and viewing)
- Starts Step Functions executions
- Views execution history
- Reads S3 bucket
- Views CloudWatch logs

To assume the user role:
```bash
USER_ROLE_ARN=$(terraform output -raw stepfunctions_user_role_arn)

aws sts assume-role \
  --role-arn $USER_ROLE_ARN \
  --role-session-name "stepfunctions-user-session"
```

## Mock APIs with Bearer Token Authentication

The mock Lambda functions simulate external APIs that require bearer token authentication. Tokens are stored in AWS Secrets Manager.

### Retrieve API Tokens

```bash
SECRET_NAME=$(terraform output -raw secrets_manager_arn | awk -F: '{print $NF}')

aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --query SecretString \
  --output text | jq
```

### Replace Mock APIs with Real APIs

To replace the mock Lambda functions with real external APIs:

1. Update `state-machine.json` to use HTTP tasks instead of Lambda invoke:

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::http:invoke",
  "Parameters": {
    "ApiEndpoint": "https://your-api.com/validate",
    "Method": "POST",
    "Authentication": {
      "ConnectionArn": "arn:aws:events:us-east-1:123456789012:connection/..."
    },
    "RequestBody": {
      "jiraStoryId.$": "$.workflowData.jiraStoryId",
      "packageIds.$": "$.workflowData.packageIds"
    }
  }
}
```

2. Create EventBridge Connections for authentication
3. Update IAM policies to allow Step Functions to use connections

## Jira Automation Setup

To configure Jira Automation to call the callback Lambda:

1. Go to Jira Project Settings > Automation
2. Create a new rule:
   - **Trigger**: Issue transitioned to "Done"
   - **Condition**: Issue type = Story
   - **Action**: Send web request
     - URL: `<CALLBACK_API_ENDPOINT>` (from Terraform output)
     - Method: POST
     - Headers: `Content-Type: application/json`
     - Body:
       ```json
       {
         "jiraStoryId": "{{issue.key}}",
         "message": "Story completed by {{issue.assignee.displayName}}",
         "status": "success"
       }
       ```

## Task Token Mapping

The workflow uses DynamoDB to map Jira story IDs to Step Functions task tokens:

```
┌─────────────────┬──────────────────────┬─────────────────┐
│  jiraStoryId    │     taskToken        │  executionArn   │
├─────────────────┼──────────────────────┼─────────────────┤
│  PROJ-12345     │  AAAAKgAA...         │  arn:aws:...    │
└─────────────────┴──────────────────────┴─────────────────┘
```

The table includes TTL (Time To Live) set to 24 hours to automatically clean up expired tokens.

## Monitoring and Troubleshooting

### CloudWatch Logs

All components log to CloudWatch:
- Step Functions: `/aws/vendedlogs/states/stepfunctions-poc-*`
- Lambda functions: `/aws/lambda/stepfunctions-poc-*`
- API Gateway: `/aws/apigateway/stepfunctions-poc-*`

### Common Issues

**1. Execution stuck at "Wait for Jira"**
- Check if task token was stored in DynamoDB
- Verify Jira automation is configured correctly
- Ensure callback API endpoint is accessible

**2. Mock API authentication failures**
- Check Secrets Manager for token values
- Verify Lambda has permission to read secrets
- Look at Lambda CloudWatch logs for details

**3. S3 access errors**
- Verify input file exists at specified path
- Check Step Functions role has S3 permissions
- Ensure bucket name matches in inputs

## Cost Estimation

For 1000 executions per month:
- Step Functions: ~$0.25 (state transitions)
- Lambda: ~$0.20 (invocations + duration)
- S3: ~$0.02 (storage + requests)
- DynamoDB: ~$0.00 (on-demand, low volume)
- API Gateway: ~$0.00 (HTTP API, low volume)
- **Total: ~$0.50/month**

## Cleanup

To destroy all resources:

```bash
# Delete S3 bucket contents first
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
aws s3 rm s3://$BUCKET_NAME --recursive

# Destroy infrastructure
terraform destroy
```

## Next Steps

1. **Replace mock APIs** with real external services
2. **Add authentication** to API Gateway (API keys, IAM, Cognito)
3. **Implement error notifications** (SNS, email)
4. **Add metrics and alarms** for monitoring
5. **Set up CI/CD pipeline** for automated deployments
6. **Add input validation** and sanitization
7. **Implement workflow versioning** and rollback

## References

- [AWS Step Functions Developer Guide](https://docs.aws.amazon.com/step-functions/)
- [Amazon States Language Specification](https://states-language.net/spec.html)
- [Step Functions Callback Pattern](https://docs.aws.amazon.com/step-functions/latest/dg/callback-task-sample-sqs.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Support

For issues or questions:
1. Check CloudWatch logs for errors
2. Review Step Functions execution history
3. Verify IAM permissions
4. Check Terraform state for resource details
