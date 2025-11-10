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
