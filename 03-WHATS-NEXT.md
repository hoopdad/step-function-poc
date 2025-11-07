# 🎉 Deployment Successful! What's Next?

Your Step Functions POC is now deployed and ready to test!

## 📋 Quick Test (3 Commands)

```bash
# 1. Start a workflow execution
chmod +x *.sh
./start-execution.sh

# 2. Send the Jira callback (use the story ID from step 1: PROJ-12345)
./send-callback.sh PROJ-12345 "Story completed" success

# 3. View the results (use execution ID from step 1)
./view-results.sh execution-<TIMESTAMP>
```

## 📝 Detailed Steps

### Step 1: Start an Execution

```bash
./start-execution.sh
```

**What this does:**
- Uploads `workflow-input.json` to S3
- Starts a new Step Functions execution
- Returns an execution ARN

**You'll see:**
```
✓ Execution started successfully!

Execution ARN:
  arn:aws:states:us-east-1:704855531002:stateMachine:stepfunctions-poc-dev-workflow:execution-1699385234

The workflow will pause at 'Wait for Jira Callback' step.
To complete it, run:
  ./send-callback.sh PROJ-12345 'Story completed' success
```

### Step 2: Monitor in AWS Console

Open the AWS Console link provided (or navigate manually):

1. Go to **AWS Console** → **Step Functions**
2. Click on **stepfunctions-poc-dev-workflow**
3. Click on your execution (execution-TIMESTAMP)
4. Watch the visual workflow graph

**You'll see:**
- ✅ ReadInputFromS3 (completed)
- ✅ PrepareWorkflowData (completed)
- ✅ ParallelAPIProcessing (completed)
  - ✅ Validation
  - ✅ Deployment  
  - ✅ Notification
- ✅ StoreTaskTokenInDynamoDB (completed)
- ⏸️ **Waiting...** (paused, waiting for Jira callback)

### Step 3: Send the Callback

When you're ready to complete the workflow:

```bash
./send-callback.sh PROJ-12345 "Story completed" success
```

**Parameters:**
- `PROJ-12345` - The Jira story ID (from workflow-input.json)
- `"Story completed"` - Any message you want
- `success` - Status: either `success` or `failure`

**What this does:**
- Calls the API Gateway callback endpoint
- Passes the Jira story ID to find the task token in DynamoDB
- Sends success/failure signal to Step Functions
- Workflow resumes and completes

**You'll see:**
```
✓ Callback sent successfully!

The Step Functions workflow should now resume and complete.
```

### Step 4: View the Results

```bash
./view-results.sh execution-<TIMESTAMP>
```

Replace `<TIMESTAMP>` with your actual execution ID (e.g., `execution-1699385234`)

**You'll see:**
```json
{
  "executionId": "execution-1699385234",
  "jiraStoryId": "PROJ-12345",
  "packageIds": ["pkg-001", "pkg-002"],
  "parallelResults": [...],
  "callbackMessage": "Story completed",
  "callbackStatus": "success",
  "completedAt": "2024-11-07T22:15:30Z"
}
```

Plus the execution log with details.

## 🔍 Advanced Monitoring

### Check Task Tokens in DynamoDB

```bash
aws dynamodb scan --table-name stepfunctions-poc-dev-task-tokens
```

**During execution** you'll see:
```json
{
  "jiraStoryId": "PROJ-12345",
  "taskToken": "AAAAKgAAAAIAAA...",
  "executionArn": "arn:aws:states:...",
  "createdAt": "2024-11-07T22:10:00Z"
}
```

**After callback** the item is automatically deleted.

### View CloudWatch Logs

All components log to CloudWatch:

```bash
# Step Functions logs
aws logs tail /aws/vendedlogs/states/stepfunctions-poc-dev-workflow --follow

# Callback Lambda logs
aws logs tail /aws/lambda/stepfunctions-poc-dev-callback --follow

# Store Task Token Lambda logs
aws logs tail /aws/lambda/stepfunctions-poc-dev-store-task-token --follow

# Write Outputs Lambda logs
aws logs tail /aws/lambda/stepfunctions-poc-dev-write-outputs --follow

# Mock API logs
aws logs tail /aws/lambda/stepfunctions-poc-dev-mock-validation --follow
```

### List All S3 Outputs

```bash
BUCKET=$(terraform output -raw s3_bucket_name)

# List all execution outputs
aws s3 ls s3://$BUCKET/outputs/ --recursive

# List all execution logs
aws s3 ls s3://$BUCKET/logs/ --recursive
```

## 🧪 Test Different Scenarios

### Test Success Flow
```bash
./start-execution.sh
# Wait for execution to pause
./send-callback.sh PROJ-12345 "Story marked as Done" success
```

### Test Failure Flow
```bash
./start-execution.sh
# Wait for execution to pause
./send-callback.sh PROJ-12345 "Story failed validation" failure
```

### Test with Different Jira Story
Edit `workflow-input.json`:
```json
{
  "jiraStoryId": "PROJ-67890",
  "packageIds": ["pkg-003", "pkg-004"]
}
```

Then run:
```bash
./start-execution.sh
./send-callback.sh PROJ-67890 "Different story completed" success
```

## 🎯 What's Happening Behind the Scenes

### The Complete Flow

1. **Start Execution** → Step Functions reads `inputs/workflow-input.json` from S3
2. **Parallel Processing** → Calls 3 Lambda functions simultaneously:
   - Mock Validation API (checks packages)
   - Mock Deployment API (deploys packages)
   - Mock Notification API (sends notifications)
3. **Store Task Token** → Lambda stores task token in DynamoDB with Jira story ID
4. **Wait** → Workflow pauses (can wait up to 24 hours)
5. **Jira Callback** → When ready, you call the API Gateway endpoint
6. **Resume** → Lambda retrieves task token, signals Step Functions to continue
7. **Write Outputs** → Lambda writes results and logs to S3
8. **Complete** → Workflow finishes

### Architecture in Action

```
You → start-execution.sh → Step Functions
                                  ↓
                    [3 Parallel Lambda APIs]
                                  ↓
                        Store Task Token
                            (DynamoDB)
                                  ↓
                          ⏸️ PAUSED ⏸️
                                  ↓
You → send-callback.sh → API Gateway → Callback Lambda
                                              ↓
                                      Get Task Token
                                        (DynamoDB)
                                              ↓
                                      Resume Workflow
                                              ↓
                                      Write to S3
                                              ↓
                                        ✅ DONE
```

## 📊 Your Deployed Resources

Run this to see everything:

```bash
terraform output
```

**Key Outputs:**
- `callback_api_endpoint` - API Gateway URL for Jira callbacks
- `s3_bucket_name` - S3 bucket for inputs/outputs/logs
- `state_machine_arn` - Step Functions ARN
- `dynamodb_table_name` - DynamoDB table for task tokens

## 🔗 AWS Console Quick Links

Replace `<region>` with `us-east-1`:

- **Step Functions**: https://console.aws.amazon.com/states/home?region=us-east-1
- **Lambda Functions**: https://console.aws.amazon.com/lambda/home?region=us-east-1
- **S3 Bucket**: https://console.aws.amazon.com/s3/home?region=us-east-1
- **DynamoDB Tables**: https://console.aws.amazon.com/dynamodb/home?region=us-east-1
- **CloudWatch Logs**: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups

## 🚀 Next Steps

### 1. Configure Real Jira Integration

Set up Jira Automation:
1. Go to your Jira Project → **Project Settings** → **Automation**
2. Create a rule:
   - **Trigger**: Issue transitioned to "Done"
   - **Condition**: Issue type = Story
   - **Action**: Send web request
     - URL: `$(terraform output -raw callback_api_endpoint)`
     - Method: POST
     - Headers: `Content-Type: application/json`
     - Body:
       ```json
       {
         "jiraStoryId": "{{issue.key}}",
         "message": "Story completed by {{issue.assignee.displayName}}",
         "status": "success"
       }
       ```

### 2. Replace Mock APIs

See `README.md` section "Replace Mock APIs with Real APIs"

### 3. Production Deployment

See `PRODUCTION_CHECKLIST.md` for hardening and best practices

## ❓ Troubleshooting

### Execution Stuck?
```bash
# Check if task token is in DynamoDB
aws dynamodb get-item \
  --table-name stepfunctions-poc-dev-task-tokens \
  --key '{"jiraStoryId":{"S":"PROJ-12345"}}'
```

### Callback Not Working?
```bash
# Check Lambda logs
aws logs tail /aws/lambda/stepfunctions-poc-dev-callback --follow

# Verify API Gateway endpoint
terraform output callback_api_endpoint
```

### No Results in S3?
```bash
# Check Step Functions execution status
STATE_MACHINE_ARN=$(terraform output -raw state_machine_arn)
aws stepfunctions list-executions --state-machine-arn $STATE_MACHINE_ARN

# Check write-outputs Lambda logs
aws logs tail /aws/lambda/stepfunctions-poc-dev-write-outputs --follow
```

## 🎉 Success!

You now have a fully functional Step Functions workflow with Jira callback integration!

**Test it end-to-end:**
```bash
./start-execution.sh && sleep 5 && ./send-callback.sh PROJ-12345 "Done" success
```

---

**Need help?** Check the comprehensive documentation:
- `README.md` - Full documentation
- `QUICKSTART.md` - 5-minute guide
- `DIAGRAMS.md` - Architecture diagrams
- `PROJECT_SUMMARY.md` - Complete overview
