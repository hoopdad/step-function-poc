# Workflow Diagrams

## High-Level Architecture

```mermaid
graph TB
    User[User/API] -->|Upload Input| S3[S3 Bucket<br/>inputs/]
    User -->|Start Execution| SF[Step Functions<br/>State Machine]
    SF -->|Read Input| S3
    
    SF -->|Invoke| Lambda1[Validation API<br/>Lambda]
    SF -->|Invoke| Lambda2[Deployment API<br/>Lambda]
    SF -->|Invoke| Lambda3[Notification API<br/>Lambda]
    
    Lambda1 -.->|Check Token| SM[Secrets Manager<br/>API Tokens]
    Lambda2 -.->|Check Token| SM
    Lambda3 -.->|Check Token| SM
    
    SF -->|Store Token| DDB[(DynamoDB<br/>Task Tokens)]
    SF -->|Wait...| Wait[⏸️ Paused<br/>Waiting for Callback]
    
    Jira[Jira Automation<br/>Story = Done] -->|Webhook| APIGW[API Gateway]
    APIGW -->|Invoke| LambdaCB[Callback Lambda]
    LambdaCB -->|Get Token| DDB
    LambdaCB -->|SendTaskSuccess| SF
    
    SF -->|Resume| Process[Process Result]
    Process -->|Write Results| S3Out[S3 Bucket<br/>outputs/]
    Process -->|Write Logs| S3Log[S3 Bucket<br/>logs/]
    
    SF -->|Logs| CW[CloudWatch Logs]
    Lambda1 -->|Logs| CW
    Lambda2 -->|Logs| CW
    Lambda3 -->|Logs| CW
    LambdaCB -->|Logs| CW
    
    style Wait fill:#ffeb3b
    style SF fill:#4caf50
    style DDB fill:#2196f3
    style Jira fill:#ff9800
```

## Step Functions State Machine Flow

```mermaid
stateDiagram-v2
    [*] --> ReadInputFromS3
    
    ReadInputFromS3 --> PrepareWorkflowData: Success
    ReadInputFromS3 --> HandleS3ReadError: Error
    
    PrepareWorkflowData --> ParallelAPIProcessing
    
    state ParallelAPIProcessing {
        [*] --> ValidationBranch
        [*] --> DeploymentBranch
        [*] --> NotificationBranch
        
        state ValidationBranch {
            CallValidation --> CheckValidation
            CheckValidation --> ValidationSuccess: 200
            CheckValidation --> ValidationFailed: Error
        }
        
        state DeploymentBranch {
            CallDeployment --> CheckDeployment
            CheckDeployment --> DeploymentSuccess: 200
            CheckDeployment --> DeploymentFailed: Error
        }
        
        state NotificationBranch {
            CallNotification --> NotificationSuccess: Success
            CallNotification --> NotificationWarning: Error<br/>(non-blocking)
        }
        
        ValidationSuccess --> [*]
        DeploymentSuccess --> [*]
        NotificationSuccess --> [*]
        NotificationWarning --> [*]
    }
    
    ParallelAPIProcessing --> StoreTaskToken: All Complete
    ParallelAPIProcessing --> HandleParallelError: Any Critical Failure
    
    StoreTaskToken --> WaitForCallback: Token Stored
    WaitForCallback --> ProcessCallbackResult: Callback Received
    WaitForCallback --> HandleCallbackError: Timeout/Error
    
    ProcessCallbackResult --> WriteResultsToS3
    WriteResultsToS3 --> WriteExecutionLogToS3
    WriteExecutionLogToS3 --> WorkflowComplete
    WorkflowComplete --> [*]
    
    HandleS3ReadError --> WriteErrorToS3
    HandleParallelError --> WriteErrorToS3
    HandleCallbackError --> WriteErrorToS3
    WriteErrorToS3 --> WorkflowFailed
    WorkflowFailed --> [*]
```

## Callback Sequence

```mermaid
sequenceDiagram
    participant SF as Step Functions
    participant DDB as DynamoDB
    participant Jira as Jira Automation
    participant APIGW as API Gateway
    participant Lambda as Callback Lambda
    
    Note over SF: Workflow executing...
    SF->>DDB: Store task token<br/>Key: jiraStoryId<br/>Value: taskToken
    Note over SF: 🔒 PAUSED<br/>Waiting for callback
    
    Note over Jira: Story status → Done
    Jira->>APIGW: POST /callback<br/>{jiraStoryId, message, status}
    APIGW->>Lambda: Invoke with payload
    
    Lambda->>DDB: Get task token<br/>for jiraStoryId
    DDB-->>Lambda: Return taskToken
    
    alt Success Status
        Lambda->>SF: SendTaskSuccess<br/>(taskToken, output)
    else Failure Status
        Lambda->>SF: SendTaskFailure<br/>(taskToken, error)
    end
    
    Lambda->>DDB: Delete task token<br/>(cleanup)
    Lambda-->>APIGW: 200 OK
    APIGW-->>Jira: Success response
    
    Note over SF: 🔓 RESUMED<br/>Continue execution
    SF->>SF: Process callback result
    SF->>SF: Write results to S3
```

## IAM Roles and Permissions Flow

```mermaid
graph LR
    subgraph "Step Functions Execution"
        SF[Step Functions<br/>State Machine]
        SFRole[stepfunctions-<br/>execution-role]
    end
    
    subgraph "Lambda Functions"
        L1[Mock APIs<br/>3x Lambdas]
        L2[Callback<br/>Lambda]
        LRole1[lambda-mock-<br/>api-role]
        LRole2[lambda-<br/>callback-role]
    end
    
    subgraph "Users"
        User[User/Developer]
        UserRole[stepfunctions-<br/>user-role]
    end
    
    subgraph "AWS Services"
        S3[(S3)]
        DDB[(DynamoDB)]
        SM[Secrets<br/>Manager]
        CW[CloudWatch<br/>Logs]
    end
    
    SF -.assumes.-> SFRole
    L1 -.assumes.-> LRole1
    L2 -.assumes.-> LRole2
    User -.assumes.-> UserRole
    
    SFRole -->|invoke| L1
    SFRole -->|read/write| S3
    SFRole -->|put/get| DDB
    SFRole -->|get| SM
    SFRole -->|write| CW
    
    LRole1 -->|get| SM
    LRole1 -->|write| CW
    
    LRole2 -->|SendTaskSuccess/Failure| SF
    LRole2 -->|get/delete| DDB
    LRole2 -->|write| CW
    
    UserRole -->|start/describe| SF
    UserRole -->|read| S3
    UserRole -->|read| CW
```

## Data Flow Through S3

```mermaid
graph LR
    subgraph "S3 Bucket Structure"
        S3[S3 Root]
        S3 --> Inputs[inputs/]
        S3 --> Outputs[outputs/]
        S3 --> Logs[logs/]
        
        Inputs --> InputFile[workflow-input.json]
        Outputs --> OutDir[execution-id/]
        OutDir --> Result[result.json]
        Logs --> LogDir[execution-id/]
        LogDir --> ExecLog[execution.log]
        LogDir --> ErrLog[error.json]
    end
    
    User[User] -->|Upload| InputFile
    SF[Step Functions] -->|Read| InputFile
    SF -->|Write Success| Result
    SF -->|Write Always| ExecLog
    SF -->|Write on Error| ErrLog
    User -->|Download| Result
    
    style InputFile fill:#4caf50
    style Result fill:#2196f3
    style ExecLog fill:#ff9800
    style ErrLog fill:#f44336
```

---

## How to Use These Diagrams

These Mermaid diagrams will render automatically in:
- GitHub README files
- GitLab
- Many Markdown editors
- Mermaid Live Editor: https://mermaid.live

Copy any diagram into the Mermaid Live Editor to customize or export as PNG/SVG.
