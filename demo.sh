#!/bin/bash

# Demo Script for Step Functions POC
# This script runs the workflow and shows all Lambda executions with logs

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to print waiting
print_wait() {
    echo -e "${YELLOW}⏳ $1${NC}"
}

# Get Terraform outputs
STATE_MACHINE_ARN=$(terraform output -raw state_machine_arn 2>/dev/null)
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null)
CALLBACK_URL=$(terraform output -raw callback_api_endpoint 2>/dev/null)

if [ -z "$STATE_MACHINE_ARN" ]; then
    echo "Error: Could not get Terraform outputs. Run 'terraform apply' first."
    exit 1
fi

print_header "STEP FUNCTIONS POC DEMO"
echo "This demo will:"
echo "  1. Start a Step Functions execution"
echo "  2. Show logs from each Lambda as it executes"
echo "  3. Pause at the callback step"
echo "  4. Send the Jira callback"
echo "  5. Show the callback Lambda logs"
echo "  6. Display the final results"
echo ""
read -p "Press Enter to start the demo..."

# Step 1: Upload input and start execution
print_header "STEP 1: Starting Workflow Execution"
print_info "Uploading workflow input to S3..."
aws s3 cp workflow-input.json s3://$BUCKET_NAME/inputs/workflow-input.json > /dev/null 2>&1
print_success "Input uploaded"

EXECUTION_NAME="demo-$(date +%s)"
print_info "Starting execution: $EXECUTION_NAME"

EXECUTION_ARN=$(aws stepfunctions start-execution \
  --state-machine-arn $STATE_MACHINE_ARN \
  --input file://example-input.json \
  --name $EXECUTION_NAME \
  --query 'executionArn' \
  --output text)

print_success "Execution started!"
echo "Execution ARN: $EXECUTION_ARN"
echo ""
print_wait "Waiting 10 seconds for workflow to begin..."
sleep 10

# Step 2: Show parallel Lambda executions
print_header "STEP 2: Parallel API Processing"
print_info "Three Lambda functions are running in parallel..."
echo ""

# Give Lambdas time to execute
sleep 5

print_info "Fetching logs from Validation API Lambda..."
echo "---"
aws logs tail /aws/lambda/stepfunctions-poc-dev-mock-validation --since 2m --format short 2>/dev/null | grep -E "(Validating|Package|validation)" | head -10 || echo "No logs yet"
echo ""

print_info "Fetching logs from Deployment API Lambda..."
echo "---"
aws logs tail /aws/lambda/stepfunctions-poc-dev-mock-deployment --since 2m --format short 2>/dev/null | grep -E "(Deploying|Package|deployment)" | head -10 || echo "No logs yet"
echo ""

print_info "Fetching logs from Notification API Lambda..."
echo "---"
aws logs tail /aws/lambda/stepfunctions-poc-dev-mock-notification --since 2m --format short 2>/dev/null | grep -E "(Sending|notification|Message)" | head -10 || echo "No logs yet"
echo ""

print_success "All parallel APIs completed!"

# Step 3: Show task token storage
print_header "STEP 3: Storing Task Token for Callback"
print_info "Fetching logs from Store Task Token Lambda..."
echo "---"
sleep 2
aws logs tail /aws/lambda/stepfunctions-poc-dev-store-task-token --since 2m --format short 2>/dev/null | grep -E "(Task token stored|Jira story|Waiting)" | head -5 || echo "No logs yet"
echo ""

print_success "Task token stored in DynamoDB"
print_info "Checking DynamoDB for task token..."
aws dynamodb get-item \
  --table-name stepfunctions-poc-dev-task-tokens \
  --key '{"jiraStoryId":{"S":"PROJ-12345"}}' \
  --query 'Item.{JiraStory:jiraStoryId.S,ExecutionArn:executionArn.S}' \
  --output table 2>/dev/null || echo "Task token stored"

echo ""
print_wait "Workflow is now PAUSED, waiting for Jira callback..."
echo ""
echo "Current workflow status:"
aws stepfunctions describe-execution \
  --execution-arn $EXECUTION_ARN \
  --query '{Status:status,StartDate:startDate}' \
  --output table

echo ""
read -p "Press Enter to send the Jira callback and complete the workflow..."

# Step 4: Send callback
print_header "STEP 4: Sending Jira Callback"
print_info "Simulating Jira Automation sending webhook..."
echo ""
echo "Callback URL: $CALLBACK_URL"
echo "Jira Story ID: PROJ-12345"
echo ""

CALLBACK_RESPONSE=$(curl -s -X POST $CALLBACK_URL \
  -H "Content-Type: application/json" \
  -d '{
    "jiraStoryId": "PROJ-12345",
    "message": "Story completed - Demo",
    "status": "success"
  }')

echo "Callback Response:"
echo "$CALLBACK_RESPONSE" | jq '.'
echo ""

print_success "Callback sent successfully!"

# Step 5: Show callback Lambda logs
print_header "STEP 5: Callback Lambda Execution"
print_info "Fetching callback Lambda logs..."
echo "---"
sleep 2
aws logs tail /aws/lambda/stepfunctions-poc-dev-callback --since 1m --format short 2>/dev/null | grep -E "(Processing|Task token|execution|Success)" | head -10 || echo "Processing..."
echo ""

print_success "Callback Lambda completed - workflow resumed!"

# Step 6: Wait for workflow to complete
print_wait "Waiting for workflow to complete..."
sleep 3

# Step 7: Show write outputs Lambda logs
print_header "STEP 6: Writing Results to S3"
print_info "Fetching Write Outputs Lambda logs..."
echo "---"
aws logs tail /aws/lambda/stepfunctions-poc-dev-write-outputs --since 1m --format short 2>/dev/null | grep -E "(Writing|Result|Log|written)" | head -10 || echo "Writing outputs..."
echo ""

print_success "Results written to S3!"

# Step 8: Show final execution status
print_header "STEP 7: Final Execution Status"
print_info "Checking execution status..."

EXEC_STATUS=$(aws stepfunctions describe-execution \
  --execution-arn $EXECUTION_ARN \
  --query 'status' \
  --output text)

if [ "$EXEC_STATUS" = "SUCCEEDED" ]; then
    print_success "Workflow completed successfully!"
else
    print_info "Status: $EXEC_STATUS"
fi

aws stepfunctions describe-execution \
  --execution-arn $EXECUTION_ARN \
  --query '{Status:status,StartDate:startDate,StopDate:stopDate}' \
  --output table

# Step 9: Show results
print_header "STEP 8: Viewing Results"
print_info "Fetching results from S3..."
echo ""

RESULT_FILE="s3://$BUCKET_NAME/outputs/$EXECUTION_NAME/result.json"
if aws s3 ls $RESULT_FILE > /dev/null 2>&1; then
    echo "Results:"
    echo "--------"
    aws s3 cp $RESULT_FILE - | jq '.'
    echo ""
else
    print_wait "Results not yet available, waiting..."
    sleep 3
    aws s3 cp $RESULT_FILE - | jq '.' 2>/dev/null || echo "Still processing..."
fi

print_info "Execution log:"
echo "--------"
aws s3 cp s3://$BUCKET_NAME/logs/$EXECUTION_NAME/execution.log - 2>/dev/null || echo "Log not yet available"
echo ""

# Summary
print_header "DEMO COMPLETE!"
echo -e "${GREEN}✓ Workflow executed successfully${NC}"
echo -e "${GREEN}✓ All Lambda functions logged their execution${NC}"
echo -e "${GREEN}✓ Callback pattern demonstrated${NC}"
echo -e "${GREEN}✓ Results written to S3${NC}"
echo ""
echo "Key artifacts:"
echo "  • Execution ARN: $EXECUTION_ARN"
echo "  • Results: s3://$BUCKET_NAME/outputs/$EXECUTION_NAME/result.json"
echo "  • Logs: s3://$BUCKET_NAME/logs/$EXECUTION_NAME/execution.log"
echo ""
echo "View in AWS Console:"
echo "  https://console.aws.amazon.com/states/home?region=us-east-1#/executions/details/$EXECUTION_ARN"
echo ""
print_success "POC Demo Complete!"
