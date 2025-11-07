#!/bin/bash

# Get state machine ARN from Terraform
STATE_MACHINE_ARN=$(terraform output -raw state_machine_arn 2>/dev/null)

if [ -z "$STATE_MACHINE_ARN" ]; then
    echo "Error: Could not get state machine ARN from Terraform outputs"
    echo "Make sure you've run 'terraform apply' successfully"
    exit 1
fi

# Get bucket name
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null)

if [ -z "$BUCKET_NAME" ]; then
    echo "Error: Could not get S3 bucket name from Terraform outputs"
    exit 1
fi

# Generate execution name
EXECUTION_NAME="execution-$(date +%s)"

echo "=========================================="
echo "Starting Step Functions Execution"
echo "=========================================="
echo ""
echo "State Machine: $STATE_MACHINE_ARN"
echo "Execution Name: $EXECUTION_NAME"
echo ""

# Upload the workflow input to S3 first
echo "Uploading workflow input to S3..."
aws s3 cp workflow-input.json s3://$BUCKET_NAME/inputs/workflow-input.json
echo "✓ Input uploaded to s3://$BUCKET_NAME/inputs/workflow-input.json"
echo ""

# Start execution
echo "Starting execution..."
EXECUTION_ARN=$(aws stepfunctions start-execution \
  --state-machine-arn $STATE_MACHINE_ARN \
  --input file://example-input.json \
  --name $EXECUTION_NAME \
  --query 'executionArn' \
  --output text)

if [ $? -eq 0 ]; then
    echo "✓ Execution started successfully!"
    echo ""
    echo "Execution ARN:"
    echo "  $EXECUTION_ARN"
    echo ""
    echo "Monitor execution:"
    echo "  aws stepfunctions describe-execution --execution-arn $EXECUTION_ARN"
    echo ""
    echo "Or visit AWS Console:"
    echo "  https://console.aws.amazon.com/states/home?region=us-east-1#/executions/details/$EXECUTION_ARN"
    echo ""
    echo "The workflow will pause at 'Wait for Jira Callback' step."
    echo "To complete it, run:"
    echo "  ./send-callback.sh PROJ-12345 'Story completed' success"
else
    echo "✗ Failed to start execution"
    exit 1
fi
