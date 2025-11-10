# Step Functions POC Demo Output

## ========================================
## STEP FUNCTIONS POC DEMO
## ========================================

This demo will:
  1. Start a Step Functions execution
  2. Show logs from each Lambda as it executes
  3. Pause at the callback step
  4. Send the Jira callback
  5. Show the callback Lambda logs
  6. Display the final results

Press Enter to start the demo...

## ========================================
## STEP 1: Starting Workflow Execution
## ========================================

ℹ Viewing workflow input file...

Input File (workflow-input.json):
---
```json
{
  "jiraStoryId": "PROJ-12345",
  "packageIds": [
    "pkg-001",
    "pkg-002"
  ],
  "metadata": {
    "environment": "production",
    "requestedBy": "john.doe@example.com",
    "priority": "high",
    "notes": "Deployment for Q4 release"
  }
}
```

ℹ Uploading workflow input to S3...

✓ Input uploaded

ℹ Starting execution: demo-1762794837

✓ Execution started!

Execution ARN: arn:aws:states:us-east-1:704855531002:execution:stepfunctions-poc-dev-workflow:demo-1762794837

## ========================================
## ⏸️  OPEN THIS URL NOW!
## ========================================

https://console.aws.amazon.com/states/home?region=us-east-1#/executions/details/arn:aws:states:us-east-1:704855531002:execution:stepfunctions-poc-dev-workflow:demo-1762794837

Open the link above to watch the workflow execute in real-time!
You'll see the parallel branches running...

⏳ Waiting 10 seconds for you to open the console...

✓ Continuing demo...                    


## ========================================
## STEP 2: Parallel API Processing
## ========================================

ℹ Three Lambda functions are running in parallel...

ℹ Fetching logs from Validation API Lambda...
---
```
2025-11-10T17:13:59 2025-11-10T17:13:59.805Z    99e3f87f-f772-45de-8aff-ec6f466a8e72    INFO    Validating packages for Jira story: PROJ-12345
2025-11-10T17:13:59 2025-11-10T17:13:59.805Z    99e3f87f-f772-45de-8aff-ec6f466a8e72    INFO    Package IDs: pkg-001, pkg-002
2025-11-10T17:13:59 2025-11-10T17:13:59.805Z    99e3f87f-f772-45de-8aff-ec6f466a8e72    INFO    Processing validation (demo mode: 10119ms delay)...
```

ℹ Fetching logs from Deployment API Lambda...
---
```
2025-11-10T17:13:59 2025-11-10T17:13:59.874Z    019199b3-2cbc-4b56-99a4-cd53168d3cb6    INFO    Deploying packages for Jira story: PROJ-12345
2025-11-10T17:13:59 2025-11-10T17:13:59.874Z    019199b3-2cbc-4b56-99a4-cd53168d3cb6    INFO    Package IDs: pkg-001, pkg-002
2025-11-10T17:13:59 2025-11-10T17:13:59.874Z    019199b3-2cbc-4b56-99a4-cd53168d3cb6    INFO    Processing deployment (demo mode: 12171ms delay)...
```

ℹ Fetching logs from Notification API Lambda...
---
```
2025-11-10T17:13:59 2025-11-10T17:13:59.945Z    c3b10816-8278-4998-81f4-9baeeb5923d3    INFO    Sending notification for Jira story: PROJ-12345
2025-11-10T17:13:59 2025-11-10T17:13:59.945Z    c3b10816-8278-4998-81f4-9baeeb5923d3    INFO    Message: Workflow processing started
2025-11-10T17:13:59 2025-11-10T17:13:59.945Z    c3b10816-8278-4998-81f4-9baeeb5923d3    INFO    Processing notification (demo mode: 12847ms delay)...
```

✓ All parallel APIs completed!

## ========================================
## STEP 3: Storing Task Token for Callback
## ========================================

ℹ Fetching logs from Store Task Token Lambda...
---
```
2025-11-10T17:14:14 2025-11-10T17:14:14.555Z    0dde32fa-2000-4b76-96ef-d4951c44fa33    INFO    Task token stored for Jira story: PROJ-12345
2025-11-10T17:14:14 2025-11-10T17:14:14.555Z    0dde32fa-2000-4b76-96ef-d4951c44fa33    INFO    Waiting for callback from Jira...
```

✓ Task token stored in DynamoDB

ℹ Checking DynamoDB for task token...
```
------------------------------------------------------------------------------------------------------------------
|                                                     GetItem                                                    |
+--------------------------------------------------------------------------------------------------+-------------+
|                                           ExecutionArn                                           |  JiraStory  |
+--------------------------------------------------------------------------------------------------+-------------+
|  arn:aws:states:us-east-1:704855531002:execution:stepfunctions-poc-dev-workflow:demo-1762794837  |  PROJ-12345 |
+--------------------------------------------------------------------------------------------------+-------------+
```

⏳ Workflow is now PAUSED, waiting for Jira callback...

Current workflow status:
```
-------------------------------------------------
|               DescribeExecution               |
+------------------------------------+----------+
|              StartDate             | Status   |
+------------------------------------+----------+
|  2025-11-10T12:13:58.915000-05:00  |  RUNNING |
+------------------------------------+----------+
```

Press Enter to send the Jira callback and complete the workflow...

## ========================================
## STEP 4: Sending Jira Callback
## ========================================

ℹ Simulating Jira Automation sending webhook...

Callback URL: https://0z700woirh.execute-api.us-east-1.amazonaws.com/callback

Jira Story ID: PROJ-12345

Callback Response:
```json
{
  "message": "Callback processed successfully",
  "jiraStoryId": "PROJ-12345",
  "executionArn": "arn:aws:states:us-east-1:704855531002:execution:stepfunctions-poc-dev-workflow:demo-1762794837",
  "status": "success"
}
```

✓ Callback sent successfully!

## ========================================
## STEP 5: Callback Lambda Execution
## ========================================

ℹ Fetching callback Lambda logs...
---

✓ Callback Lambda completed - workflow resumed!

⏳ Waiting for workflow to complete...

## ========================================
## STEP 6: Writing Results to S3
## ========================================

ℹ Fetching Write Outputs Lambda logs...
---
```
2025-11-10T17:14:44 2025-11-10T17:14:44.378Z    3aa1df89-f73a-43ea-806d-3fc367aac7e1    INFO    Writing outputs to S3: {
  "callbackResult": {
  "finalResult": {
    "parallelResults": [
2025-11-10T17:14:45 2025-11-10T17:14:45.490Z    3aa1df89-f73a-43ea-806d-3fc367aac7e1    INFO    Result written to s3://stepfunctions-poc-dev-workflow-704855531002/outputs/demo-1762794837/result.json
2025-11-10T17:14:45 2025-11-10T17:14:45.531Z    3aa1df89-f73a-43ea-806d-3fc367aac7e1    INFO    Log written to s3://stepfunctions-poc-dev-workflow-704855531002/logs/demo-1762794837/execution.log
```

✓ Results written to S3!

## ========================================
## STEP 7: Final Execution Status
## ========================================

ℹ Checking execution status...

✓ Workflow completed successfully!
```
---------------------------------------------------------------------------------------
|                                  DescribeExecution                                  |
+-----------------------------------+------------+------------------------------------+
|             StartDate             |  Status    |             StopDate               |
+-----------------------------------+------------+------------------------------------+
|  2025-11-10T12:13:58.915000-05:00 |  SUCCEEDED |  2025-11-10T12:14:45.634000-05:00  |
+-----------------------------------+------------+------------------------------------+
```

## ========================================
## STEP 8: Viewing Results
## ========================================

ℹ Fetching results from S3...

Results:
--------
```json
{
  "executionId": "demo-1762794837",
  "completedAt": "2025-11-10T17:14:43.351Z",
  "callbackStatus": "success",
  "jiraStoryId": "PROJ-12345",
  "parallelResults": [
    {
      "status": "success",
      "message": "Validation completed successfully"
    },
    {
      "status": "success",
      "message": "Deployment completed successfully"
    },
    {
      "status": "success",
      "message": "Notification sent successfully"
    }
  ],
  "callbackMessage": "Story completed - Demo",
  "packageIds": [
    "pkg-001",
    "pkg-002"
  ]
}
```

ℹ Execution log:
--------
```
Execution ID: demo-1762794837
Jira Story: PROJ-12345
Start Time: 2025-11-10T17:13:58.915Z
Completed At: 2025-11-10T17:14:43.351Z
Status: SUCCESS
Callback Message: Story completed - Demo
```


## ========================================
## DEMO COMPLETE!
## ========================================

✓ Workflow executed successfully

✓ All Lambda functions logged their execution

✓ Callback pattern demonstrated

✓ Results written to S3

Key artifacts:
  • Execution ARN: arn:aws:states:us-east-1:704855531002:execution:stepfunctions-poc-dev-workflow:demo-1762794837
  • Results: s3://stepfunctions-poc-dev-workflow-704855531002/outputs/demo-1762794837/result.json
  • Logs: s3://stepfunctions-poc-dev-workflow-704855531002/logs/demo-1762794837/execution.log

View in AWS Console:
  https://console.aws.amazon.com/states/home?region=us-east-1#/executions/details/arn:aws:states:us-east-1:704855531002:execution:stepfunctions-poc-dev-workflow:demo-1762794837

✓ POC Demo Complete!
