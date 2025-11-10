#!/bin/bash
STATE_MACHINE_ARN=$(terraform -chdir=infrastructure output -raw state_machine_arn)
EXECUTION_NAME="execution-$(date +%s)"

echo "Starting Step Functions execution..."
EXECUTION_ARN=$(aws stepfunctions start-execution \
  --state-machine-arn $STATE_MACHINE_ARN \
  --input file://example-input.json \
  --name $EXECUTION_NAME \
  --query 'executionArn' \
  --output text)

echo "Execution started: $EXECUTION_ARN"
echo ""
echo "Monitor execution:"
echo "  aws stepfunctions describe-execution --execution-arn $EXECUTION_ARN"
echo ""
echo "Or visit AWS Console:"
echo "  https://console.aws.amazon.com/states/home?region=us-east-1#/executions/details/$EXECUTION_ARN"
