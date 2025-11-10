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
