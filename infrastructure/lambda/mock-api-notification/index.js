const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION });
const SECRET_NAME = process.env.SECRET_NAME;
const TOKEN_KEY = process.env.TOKEN_KEY;

let cachedToken = null;

/**
 * Retrieve the bearer token from Secrets Manager
 */
async function getBearerToken() {
    if (cachedToken) {
        return cachedToken;
    }

    try {
        const command = new GetSecretValueCommand({
            SecretId: SECRET_NAME
        });
        
        const response = await secretsClient.send(command);
        const secrets = JSON.parse(response.SecretString);
        cachedToken = secrets[TOKEN_KEY];
        
        return cachedToken;
    } catch (error) {
        console.error('Error retrieving secret:', error);
        throw error;
    }
}

/**
 * Validate authorization header
 */
async function validateAuth(authHeader) {
    if (!authHeader) {
        return { valid: false, error: 'Missing Authorization header' };
    }

    const expectedToken = await getBearerToken();
    const expectedAuth = `Bearer ${expectedToken}`;

    if (authHeader !== expectedAuth) {
        return { valid: false, error: 'Invalid bearer token' };
    }

    return { valid: true };
}

/**
 * Mock Notification API Lambda Handler
 * Simulates an external API that sends notifications
 */
exports.handler = async (event) => {
    console.log('Notification API received event:', JSON.stringify(event, null, 2));

    try {
        // Extract authorization header
        const authHeader = event.authorization || event.Authorization;
        
        // Validate authentication (optional for internal invocations)
        if (authHeader) {
            const authResult = await validateAuth(authHeader);
            if (!authResult.valid) {
                console.error('Authentication failed:', authResult.error);
                return {
                    statusCode: 401,
                    body: {
                        error: 'Unauthorized',
                        message: authResult.error
                    }
                };
            }
            console.log('Authentication successful');
        } else {
            console.log('No authorization header provided - assuming internal invocation');
        }

        const { jiraStoryId, action, message } = event;

        // Validate required parameters
        if (!jiraStoryId || !message) {
            return {
                statusCode: 400,
                body: {
                    error: 'Bad Request',
                    message: 'Missing required parameters: jiraStoryId, message'
                }
            };
        }

        console.log(`Sending notification for Jira story: ${jiraStoryId}`);
        console.log(`Message: ${message}`);

        // Demo delay: Add random pause to allow viewing workflow in AWS Console
        const demoDelay = Math.floor(Math.random() * 6000) + 10000; // 10-15 seconds
        console.log(`Processing notification (demo mode: ${demoDelay}ms delay)...`);
        await new Promise(resolve => setTimeout(resolve, demoDelay));

        // Mock notification channels
        const channels = ['email', 'slack', 'teams'];
        const notificationResults = channels.map(channel => ({
            channel: channel,
            status: 'sent',
            messageId: `msg-${Date.now()}-${channel}`,
            sentAt: new Date().toISOString()
        }));

        return {
            statusCode: 200,
            body: {
                success: true,
                jiraStoryId: jiraStoryId,
                action: action,
                message: message,
                notificationStatus: 'SENT',
                channels: notificationResults,
                totalRecipients: 5,
                timestamp: new Date().toISOString(),
                sentBy: 'Mock Notification API v1.0'
            }
        };

    } catch (error) {
        console.error('Error in notification API:', error);
        
        return {
            statusCode: 500,
            body: {
                error: 'Internal Server Error',
                message: error.message,
                timestamp: new Date().toISOString()
            }
        };
    }
};
