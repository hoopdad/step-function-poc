# 🚀 Quick Reference Card

## Test Your Deployment (3 Commands)

```bash
# 1. Make scripts executable
chmod +x *.sh

# 2. Start execution
./start-execution.sh

# 3. Send callback (wait for step 2 to pause first)
./send-callback.sh PROJ-12345 "Story completed" success

# 4. View results (optional)
./view-results.sh execution-<YOUR_TIMESTAMP>
```

## Helper Scripts

| Script | Purpose | Example |
|--------|---------|---------|
| `start-execution.sh` | Start a new workflow | `./start-execution.sh` |
| `send-callback.sh` | Resume paused workflow | `./send-callback.sh PROJ-12345 "Done" success` |
| `view-results.sh` | View execution results | `./view-results.sh execution-1699385234` |

## AWS Console Links

- **Step Functions**: AWS Console → Step Functions → stepfunctions-poc-dev-workflow
- **Lambda**: AWS Console → Lambda → Filter: "stepfunctions-poc-dev"
- **S3**: AWS Console → S3 → stepfunctions-poc-dev-workflow-*
- **DynamoDB**: AWS Console → DynamoDB → stepfunctions-poc-dev-task-tokens

## Useful Commands

```bash
# View Terraform outputs
terraform output

# Get API endpoint
terraform output callback_api_endpoint

# Get S3 bucket name
terraform output s3_bucket_name

# List S3 outputs
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/outputs/

# View CloudWatch logs
aws logs tail /aws/vendedlogs/states/stepfunctions-poc-dev-workflow --follow

# Check DynamoDB for active task tokens
aws dynamodb scan --table-name stepfunctions-poc-dev-task-tokens

# List all executions
aws stepfunctions list-executions \
  --state-machine-arn $(terraform output -raw state_machine_arn)
```

## Workflow States

1. ✅ **ReadInputFromS3** - Reads workflow-input.json
2. ✅ **PrepareWorkflowData** - Parses input data
3. ✅ **ParallelAPIProcessing** - Calls 3 APIs in parallel
4. ✅ **StoreTaskTokenInDynamoDB** - Stores callback token
5. ⏸️ **[PAUSED]** - Waiting for Jira callback...
6. ✅ **ProcessCallbackResult** - Processes callback
7. ✅ **WriteOutputsToS3** - Writes results
8. ✅ **WorkflowComplete** - Done!

## Input File Format

`workflow-input.json`:
```json
{
  "jiraStoryId": "PROJ-12345",
  "packageIds": ["pkg-001", "pkg-002"]
}
```

## Callback Format

```bash
curl -X POST <API_GATEWAY_URL>/callback \
  -H "Content-Type: application/json" \
  -d '{
    "jiraStoryId": "PROJ-12345",
    "message": "Story completed",
    "status": "success"
  }'
```

Or use the helper:
```bash
./send-callback.sh PROJ-12345 "Story completed" success
```

## File Locations in S3

```
stepfunctions-poc-dev-workflow-<ACCOUNT_ID>/
├── inputs/
│   └── workflow-input.json          # Input data
├── outputs/
│   └── execution-<ID>/
│       └── result.json              # Execution results
└── logs/
    └── execution-<ID>/
        ├── execution.log            # Success log
        └── error.json               # Error log (if failed)
```

## Troubleshooting

| Problem | Check |
|---------|-------|
| Script not found | Run `chmod +x *.sh` |
| Execution doesn't start | Check S3 bucket has inputs/workflow-input.json |
| Stuck at callback | Check DynamoDB for task token |
| Callback fails | Check Lambda logs for callback function |
| No results in S3 | Check write-outputs Lambda logs |

## Quick Test Command

Run everything at once:
```bash
./start-execution.sh && \
  sleep 5 && \
  ./send-callback.sh PROJ-12345 "Auto-test completed" success
```

## Cost Per Execution

~$0.00002 per execution for this POC:
- Step Functions: $0.0000025
- Lambda (6 functions): ~$0.000012
- S3: ~$0.000001
- DynamoDB: ~$0.000001
- API Gateway: ~$0.000001

---

**Full Documentation**: See `03-WHATS-NEXT.md` for detailed guide
