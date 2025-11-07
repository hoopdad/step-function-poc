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
 * Mock Deployment API Lambda Handler
 * Simulates an external API that deploys packages
 */
exports.handler = async (event) => {
    console.log('Deployment API received event:', JSON.stringify(event, null, 2));

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

        const { jiraStoryId, packageIds, action } = event;

        // Validate required parameters
        if (!jiraStoryId || !packageIds || !Array.isArray(packageIds)) {
            return {
                statusCode: 400,
                body: {
                    error: 'Bad Request',
                    message: 'Missing or invalid required parameters: jiraStoryId, packageIds (array)'
                }
            };
        }

        console.log(`Deploying packages for Jira story: ${jiraStoryId}`);
        console.log(`Package IDs: ${packageIds.join(', ')}`);

        // Simulate longer deployment process with random delay
        await new Promise(resolve => setTimeout(resolve, Math.random() * 3000 + 2000));

        // Mock deployment results
        const deploymentResults = packageIds.map(pkgId => {
            // Simulate deployment - packages ending in '5' have warnings
            const hasWarning = pkgId.toString().endsWith('5');
            return {
                packageId: pkgId,
                status: 'deployed',
                environment: 'production',
                deploymentId: `deploy-${Date.now()}-${pkgId}`,
                url: `https://production.example.com/packages/${pkgId}`,
                warnings: hasWarning ? ['Package requires manual verification'] : [],
                deployedAt: new Date().toISOString()
            };
        });

        return {
            statusCode: 200,
            body: {
                success: true,
                jiraStoryId: jiraStoryId,
                action: action,
                deploymentStatus: 'COMPLETED',
                results: deploymentResults,
                totalPackages: packageIds.length,
                successfulDeployments: deploymentResults.length,
                timestamp: new Date().toISOString(),
                deployedBy: 'Mock Deployment API v1.0'
            }
        };

    } catch (error) {
        console.error('Error in deployment API:', error);
        
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
