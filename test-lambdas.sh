#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing Mock Lambda Functions${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get Lambda function names
VALIDATION_LAMBDA=$(terraform output -raw mock_validation_lambda_arn | awk -F: '{print $NF}')
DEPLOYMENT_LAMBDA=$(terraform output -raw mock_deployment_lambda_arn | awk -F: '{print $NF}')
NOTIFICATION_LAMBDA=$(terraform output -raw mock_notification_lambda_arn | awk -F: '{print $NF}')

# Test payload
TEST_PAYLOAD='{
  "jiraStoryId": "TEST-123",
  "packageIds": ["pkg-001", "pkg-002"],
  "action": "test"
}'

echo -e "${GREEN}Testing Validation Lambda...${NC}"
aws lambda invoke \
  --function-name $VALIDATION_LAMBDA \
  --payload "$TEST_PAYLOAD" \
  --cli-binary-format raw-in-base64-out \
  response-validation.json

echo "Response:"
cat response-validation.json | jq '.'
echo ""

echo -e "${GREEN}Testing Deployment Lambda...${NC}"
aws lambda invoke \
  --function-name $DEPLOYMENT_LAMBDA \
  --payload "$TEST_PAYLOAD" \
  --cli-binary-format raw-in-base64-out \
  response-deployment.json

echo "Response:"
cat response-deployment.json | jq '.'
echo ""

echo -e "${GREEN}Testing Notification Lambda...${NC}"
NOTIFICATION_PAYLOAD='{
  "jiraStoryId": "TEST-123",
  "action": "test",
  "message": "Test notification"
}'

aws lambda invoke \
  --function-name $NOTIFICATION_LAMBDA \
  --payload "$NOTIFICATION_PAYLOAD" \
  --cli-binary-format raw-in-base64-out \
  response-notification.json

echo "Response:"
cat response-notification.json | jq '.'
echo ""

# Cleanup
rm -f response-*.json

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Lambda tests completed!${NC}"
echo -e "${GREEN}========================================${NC}"
