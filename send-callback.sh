#!/bin/bash

# Get callback URL from Terraform
CALLBACK_URL=$(terraform output -raw callback_api_endpoint 2>/dev/null)

if [ -z "$CALLBACK_URL" ]; then
    echo "Error: Could not get callback API endpoint from Terraform outputs"
    echo "Make sure you've run 'terraform apply' successfully"
    exit 1
fi

# Parse arguments
if [ -z "$1" ]; then
    echo "Usage: ./send-callback.sh <JIRA_STORY_ID> [message] [status]"
    echo ""
    echo "Example:"
    echo "  ./send-callback.sh PROJ-12345 'Story completed' success"
    echo ""
    echo "Parameters:"
    echo "  JIRA_STORY_ID: Required - The Jira story ID (e.g., PROJ-12345)"
    echo "  message:       Optional - Callback message (default: 'Jira story marked as Done')"
    echo "  status:        Optional - Status: 'success' or 'failure' (default: 'success')"
    exit 1
fi

JIRA_STORY_ID=$1
MESSAGE=${2:-"Jira story marked as Done"}
STATUS=${3:-"success"}

echo "=========================================="
echo "Sending Callback to Step Functions"
echo "=========================================="
echo ""
echo "Callback URL: $CALLBACK_URL"
echo "Jira Story ID: $JIRA_STORY_ID"
echo "Message: $MESSAGE"
echo "Status: $STATUS"
echo ""

# Send callback
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $CALLBACK_URL \
  -H "Content-Type: application/json" \
  -d "{
    \"jiraStoryId\": \"$JIRA_STORY_ID\",
    \"message\": \"$MESSAGE\",
    \"status\": \"$STATUS\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "Response:"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Callback sent successfully!"
    echo ""
    echo "The Step Functions workflow should now resume and complete."
    echo "Check the AWS Console to see the execution finish."
else
    echo "✗ Callback failed with HTTP status: $HTTP_CODE"
    exit 1
fi
