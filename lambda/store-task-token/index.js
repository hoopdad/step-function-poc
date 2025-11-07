const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');

const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION });
const tableName = process.env.DYNAMODB_TABLE;

/**
 * Lambda that stores task token in DynamoDB and waits for callback
 * This is invoked by Step Functions with waitForTaskToken
 */
exports.handler = async (event, context) => {
    console.log('Received event:', JSON.stringify(event, null, 2));

    try {
        const { jiraStoryId, taskToken, executionArn, startTime } = event;

        // Validate required parameters
        if (!jiraStoryId || !taskToken) {
            throw new Error('Missing required parameters: jiraStoryId or taskToken');
        }

        // Calculate expiration time (24 hours from now)
        const expirationTime = Math.floor(Date.now() / 1000) + (24 * 60 * 60);

        // Store task token in DynamoDB
        const putCommand = new PutItemCommand({
            TableName: tableName,
            Item: {
                jiraStoryId: { S: jiraStoryId },
                taskToken: { S: taskToken },
                executionArn: { S: executionArn },
                createdAt: { S: new Date().toISOString() },
                expirationTime: { N: expirationTime.toString() }
            }
        });

        await dynamoClient.send(putCommand);
        
        console.log(`Task token stored for Jira story: ${jiraStoryId}`);
        console.log(`Execution: ${executionArn}`);
        console.log('Waiting for callback from Jira...');

        // NOTE: This Lambda will now pause and wait for SendTaskSuccess/SendTaskFailure
        // from the callback Lambda. The function will not return until the callback is received.
        // Step Functions handles this automatically with the .waitForTaskToken pattern.

    } catch (error) {
        console.error('Error storing task token:', error);
        throw error;
    }
};
