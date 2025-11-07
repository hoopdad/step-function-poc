#!/bin/bash

# Get bucket name from Terraform
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null)

if [ -z "$BUCKET_NAME" ]; then
    echo "Error: Could not get S3 bucket name from Terraform outputs"
    echo "Make sure you've run 'terraform apply' successfully"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: ./view-results.sh <EXECUTION_ID>"
    echo ""
    echo "To list all executions, run:"
    echo "  aws s3 ls s3://$BUCKET_NAME/outputs/"
    echo ""
    echo "Example:"
    echo "  ./view-results.sh execution-1699385234"
    exit 1
fi

EXECUTION_ID=$1

echo "=========================================="
echo "Viewing Results for: $EXECUTION_ID"
echo "=========================================="
echo ""

# Check if result exists
if aws s3 ls s3://$BUCKET_NAME/outputs/$EXECUTION_ID/result.json >/dev/null 2>&1; then
    echo "Results:"
    echo "--------"
    aws s3 cp s3://$BUCKET_NAME/outputs/$EXECUTION_ID/result.json - | jq '.'
    echo ""
else
    echo "✗ No result file found for execution: $EXECUTION_ID"
    echo ""
    echo "Available executions:"
    aws s3 ls s3://$BUCKET_NAME/outputs/
    exit 1
fi

# Check if execution log exists
if aws s3 ls s3://$BUCKET_NAME/logs/$EXECUTION_ID/execution.log >/dev/null 2>&1; then
    echo "Execution Log:"
    echo "--------------"
    aws s3 cp s3://$BUCKET_NAME/logs/$EXECUTION_ID/execution.log -
    echo ""
else
    echo "Note: No execution log found (workflow may have failed)"
fi

# Check for error log
if aws s3 ls s3://$BUCKET_NAME/logs/$EXECUTION_ID/error.json >/dev/null 2>&1; then
    echo "Error Log:"
    echo "----------"
    aws s3 cp s3://$BUCKET_NAME/logs/$EXECUTION_ID/error.json - | jq '.'
    echo ""
fi

echo "Files in S3:"
echo "  Result: s3://$BUCKET_NAME/outputs/$EXECUTION_ID/result.json"
echo "  Log:    s3://$BUCKET_NAME/logs/$EXECUTION_ID/execution.log"
