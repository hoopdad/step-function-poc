const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const s3Client = new S3Client({ region: process.env.AWS_REGION });
const bucketName = process.env.S3_BUCKET;

/**
 * Lambda to write workflow outputs and logs to S3
 * Handles both successful completions and errors
 */
exports.handler = async (event) => {
    console.log('Writing outputs to S3:', JSON.stringify(event, null, 2));

    try {
        const { executionId, finalResult, workflowData, callbackResult, errorDetails, isError } = event;

        if (isError) {
            // Write error log
            const errorKey = `logs/${executionId || 'unknown'}/error.json`;
            await s3Client.send(new PutObjectCommand({
                Bucket: bucketName,
                Key: errorKey,
                Body: JSON.stringify(errorDetails, null, 2),
                ContentType: 'application/json'
            }));
            console.log(`Error written to s3://${bucketName}/${errorKey}`);

            return {
                statusCode: 200,
                body: {
                    message: 'Error log written successfully',
                    errorLocation: `s3://${bucketName}/${errorKey}`
                }
            };
        }

        // Write result JSON
        const resultKey = `outputs/${executionId}/result.json`;
        await s3Client.send(new PutObjectCommand({
            Bucket: bucketName,
            Key: resultKey,
            Body: JSON.stringify(finalResult, null, 2),
            ContentType: 'application/json'
        }));
        console.log(`Result written to s3://${bucketName}/${resultKey}`);

        // Write execution log
        const logContent = `Execution ID: ${executionId}
Jira Story: ${workflowData.jiraStoryId}
Start Time: ${workflowData.startTime}
Completed At: ${finalResult.completedAt}
Status: SUCCESS
Callback Message: ${callbackResult.message}
`;

        const logKey = `logs/${executionId}/execution.log`;
        await s3Client.send(new PutObjectCommand({
            Bucket: bucketName,
            Key: logKey,
            Body: logContent,
            ContentType: 'text/plain'
        }));
        console.log(`Log written to s3://${bucketName}/${logKey}`);

        return {
            statusCode: 200,
            body: {
                message: 'Outputs written successfully',
                resultLocation: `s3://${bucketName}/${resultKey}`,
                logLocation: `s3://${bucketName}/${logKey}`
            }
        };

    } catch (error) {
        console.error('Error writing to S3:', error);
        throw error;
    }
};
