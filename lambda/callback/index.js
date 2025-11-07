const { DynamoDBClient, GetItemCommand, DeleteItemCommand } = require('@aws-sdk/client-dynamodb');
const { SFNClient, SendTaskSuccessCommand, SendTaskFailureCommand } = require('@aws-sdk/client-sfn');

const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION });
const sfnClient = new SFNClient({ region: process.env.AWS_REGION });
const tableName = process.env.DYNAMODB_TABLE;

/**
 * Lambda handler for Jira callback
 * Expected payload: { jiraStoryId, message, status }
 */
exports.handler = async (event) => {
    console.log('Received event:', JSON.stringify(event, null, 2));

    try {
        // Parse the request body
        let body;
        if (typeof event.body === 'string') {
            body = JSON.parse(event.body);
        } else {
            body = event.body;
        }

        const { jiraStoryId, message, status } = body;

        // Validate required parameters
        if (!jiraStoryId) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    error: 'Missing required parameter: jiraStoryId'
                })
            };
        }

        if (!message) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    error: 'Missing required parameter: message'
                })
            };
        }

        console.log(`Processing callback for Jira story: ${jiraStoryId}`);

        // Retrieve task token from DynamoDB
        const getItemCommand = new GetItemCommand({
            TableName: tableName,
            Key: {
                jiraStoryId: { S: jiraStoryId }
            }
        });

        const dynamoResult = await dynamoClient.send(getItemCommand);

        if (!dynamoResult.Item || !dynamoResult.Item.taskToken) {
            console.error(`Task token not found for Jira story: ${jiraStoryId}`);
            return {
                statusCode: 404,
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    error: `No active workflow found for Jira story: ${jiraStoryId}`,
                    details: 'The workflow may have already completed, timed out, or the story ID is incorrect'
                })
            };
        }

        const taskToken = dynamoResult.Item.taskToken.S;
        const executionArn = dynamoResult.Item.executionArn.S;

        console.log(`Found task token for execution: ${executionArn}`);

        // Determine if this is a success or failure based on status
        const isSuccess = !status || status.toLowerCase() === 'success' || status.toLowerCase() === 'done';

        if (isSuccess) {
            // Send task success
            const successCommand = new SendTaskSuccessCommand({
                taskToken: taskToken,
                output: JSON.stringify({
                    message: message,
                    status: 'success',
                    jiraStoryId: jiraStoryId,
                    completedAt: new Date().toISOString()
                })
            });

            await sfnClient.send(successCommand);
            console.log(`Successfully sent task success for execution: ${executionArn}`);
        } else {
            // Send task failure
            const failureCommand = new SendTaskFailureCommand({
                taskToken: taskToken,
                error: 'JiraCallbackFailure',
                cause: message
            });

            await sfnClient.send(failureCommand);
            console.log(`Successfully sent task failure for execution: ${executionArn}`);
        }

        // Delete the task token from DynamoDB (cleanup)
        const deleteCommand = new DeleteItemCommand({
            TableName: tableName,
            Key: {
                jiraStoryId: { S: jiraStoryId }
            }
        });

        await dynamoClient.send(deleteCommand);
        console.log(`Cleaned up task token for Jira story: ${jiraStoryId}`);

        // Return success response
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: 'Callback processed successfully',
                jiraStoryId: jiraStoryId,
                executionArn: executionArn,
                status: isSuccess ? 'success' : 'failure'
            })
        };

    } catch (error) {
        console.error('Error processing callback:', error);
        
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message,
                details: 'Failed to process Jira callback'
            })
        };
    }
};
