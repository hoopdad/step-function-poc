#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Step Functions POC - Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install Terraform >= 1.0"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install AWS CLI"
    exit 1
fi

if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js >= 18.x"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    print_warn "jq is not installed. Some commands may not work properly"
fi

print_info "All prerequisites met!"
echo ""

# Install Lambda dependencies
print_info "Installing Lambda dependencies..."
cd lambda/callback && npm install > /dev/null 2>&1 && cd ../..
cd lambda/mock-api-validation && npm install > /dev/null 2>&1 && cd ../..
cd lambda/mock-api-deployment && npm install > /dev/null 2>&1 && cd ../..
cd lambda/mock-api-notification && npm install > /dev/null 2>&1 && cd ../..
cd lambda/store-task-token && npm install > /dev/null 2>&1 && cd ../..
cd lambda/write-outputs && npm install > /dev/null 2>&1 && cd ../..
print_info "Lambda dependencies installed!"
echo ""

# Initialize and apply Terraform
print_info "Initializing Terraform..."
terraform -chdir=infrastructure init

echo ""
print_info "Planning Terraform deployment..."
terraform -chdir=infrastructure plan -out=tfplan

echo ""
read -p "Do you want to apply this Terraform plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    print_warn "Deployment cancelled"
    exit 0
fi

echo ""
print_info "Applying Terraform configuration..."
terraform -chdir=infrastructure apply tfplan
rm infrastructure/tfplan

echo ""
print_info "Deployment complete!"
echo ""

# Get outputs
print_info "Retrieving outputs..."
BUCKET_NAME=$(terraform -chdir=infrastructure output -raw s3_bucket_name)
STATE_MACHINE_ARN=$(terraform -chdir=infrastructure output -raw state_machine_arn)
CALLBACK_URL=$(terraform -chdir=infrastructure output -raw callback_api_endpoint)
USER_ROLE_ARN=$(terraform -chdir=infrastructure output -raw stepfunctions_user_role_arn)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "S3 Bucket: $BUCKET_NAME"
echo "State Machine ARN: $STATE_MACHINE_ARN"
echo "Callback API URL: $CALLBACK_URL"
echo "User Role ARN: $USER_ROLE_ARN"
echo ""

# Upload sample input to S3
print_info "Uploading sample workflow input to S3..."
aws s3 cp workflow-input.json s3://$BUCKET_NAME/inputs/workflow-input.json
print_info "Sample input uploaded to s3://$BUCKET_NAME/inputs/workflow-input.json"
echo ""

# Create helper scripts
print_info "Creating helper scripts..."

# Start execution script
cat > start-execution.sh << 'EOF'
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
EOF

chmod +x start-execution.sh

# Send callback script
cat > send-callback.sh << 'EOF'
#!/bin/bash
CALLBACK_URL=$(terraform -chdir=infrastructure output -raw callback_api_endpoint)

if [ -z "$1" ]; then
    echo "Usage: ./send-callback.sh <JIRA_STORY_ID> [message] [status]"
    echo ""
    echo "Example:"
    echo "  ./send-callback.sh PROJ-12345 'Story completed' success"
    exit 1
fi

JIRA_STORY_ID=$1
MESSAGE=${2:-"Jira story marked as Done"}
STATUS=${3:-"success"}

echo "Sending callback to Step Functions..."
echo "Jira Story ID: $JIRA_STORY_ID"
echo "Message: $MESSAGE"
echo "Status: $STATUS"
echo ""

curl -X POST $CALLBACK_URL \
  -H "Content-Type: application/json" \
  -d "{
    \"jiraStoryId\": \"$JIRA_STORY_ID\",
    \"message\": \"$MESSAGE\",
    \"status\": \"$STATUS\"
  }"

echo ""
echo ""
EOF

chmod +x send-callback.sh

# View results script
cat > view-results.sh << 'EOF'
#!/bin/bash
BUCKET_NAME=$(terraform -chdir=infrastructure output -raw s3_bucket_name)

if [ -z "$1" ]; then
    echo "Usage: ./view-results.sh <EXECUTION_ID>"
    echo ""
    echo "List all executions:"
    echo "  aws s3 ls s3://$BUCKET_NAME/outputs/"
    exit 1
fi

EXECUTION_ID=$1

echo "Fetching results for execution: $EXECUTION_ID"
echo ""

# Download and display result
aws s3 cp s3://$BUCKET_NAME/outputs/$EXECUTION_ID/result.json - | jq '.'

echo ""
echo "Execution log:"
aws s3 cp s3://$BUCKET_NAME/logs/$EXECUTION_ID/execution.log -
EOF

chmod +x view-results.sh

print_info "Helper scripts created:"
echo "  - start-execution.sh: Start a new Step Functions execution"
echo "  - send-callback.sh: Send Jira callback to resume workflow"
echo "  - view-results.sh: View execution results from S3"
echo ""

# Print next steps
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Next Steps${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "1. Start an execution:"
echo "   ./start-execution.sh"
echo ""
echo "2. The workflow will pause waiting for Jira callback"
echo ""
echo "3. Send callback to resume:"
echo "   ./send-callback.sh PROJ-12345 'Story completed' success"
echo ""
echo "4. View results:"
echo "   ./view-results.sh <EXECUTION_ID>"
echo ""
echo "5. Monitor in AWS Console:"
echo "   https://console.aws.amazon.com/states/home?region=us-east-1"
echo ""
echo -e "${GREEN}========================================${NC}"

print_info "Deployment completed successfully!"
