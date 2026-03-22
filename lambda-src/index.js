// Lambda handler for Strava OAuth flow
// - Routes: /auth/strava (redirect), /auth/callback (exchange code -> store tokens)
// - Reads Strava client credentials from AWS Secrets Manager (secret ARN in env: STRAVA_SECRET_ARN)
// - Writes user tokens to DynamoDB table (env: USERS_TABLE)

const AWS = require('aws-sdk');
const dynamo = new AWS.DynamoDB.DocumentClient();
const secrets = new AWS.SecretsManager();

let cachedSecrets = null; // cache secret during cold start

async function loadSecrets() {
  if (cachedSecrets) return cachedSecrets;
  const arn = process.env.STRAVA_SECRET_ARN;
  if (!arn) {
    throw new Error('Missing STRAVA_SECRET_ARN environment variable');
  }
  const resp = await secrets.getSecretValue({ SecretId: arn }).promise();
  if (!resp.SecretString) throw new Error('Secret has no string payload');
  // Expecting JSON like: {"STRAVA_CLIENT_ID":"...","STRAVA_CLIENT_SECRET":"...","STRAVA_REDIRECT_URI":"..."}
  cachedSecrets = JSON.parse(resp.SecretString);
  return cachedSecrets;
}

function redirectResponse(location) {
  return {
    statusCode: 302,
    headers: {
      Location: location,
    },
    body: '',
  };
}

exports.handler = async (event) => {
  try {
    // API Gateway HTTP API v2 gives rawPath and queryStringParameters
    const path = event.rawPath || event.path || '/';
    const method = (event.requestContext && event.requestContext.http && event.requestContext.http.method) || event.httpMethod;

    if (method === 'GET' && path === '/auth/strava') {
      const s = await loadSecrets();
      const clientId = s.STRAVA_CLIENT_ID || process.env.STRAVA_CLIENT_ID;
      const redirectUri = s.STRAVA_REDIRECT_URI || process.env.STRAVA_REDIRECT_URI;
      if (!clientId || !redirectUri) {
        return { statusCode: 500, body: 'Missing Strava client configuration' };
      }
      const params = new URLSearchParams({
        client_id: clientId,
        response_type: 'code',
        redirect_uri: redirectUri,
        scope: 'activity:read',
        approval_prompt: 'auto'
      });
      const url = `https://www.strava.com/oauth/authorize?${params.toString()}`;
      return redirectResponse(url);
    }

    if (method === 'GET' && path === '/auth/callback') {
      const q = event.queryStringParameters || {};
      const code = q.code;
      if (!code) return { statusCode: 400, body: 'Missing code parameter' };

      const s = await loadSecrets();
      const clientId = s.STRAVA_CLIENT_ID || process.env.STRAVA_CLIENT_ID;
      const clientSecret = s.STRAVA_CLIENT_SECRET || process.env.STRAVA_CLIENT_SECRET;
      const redirectUri = s.STRAVA_REDIRECT_URI || process.env.STRAVA_REDIRECT_URI;
      if (!clientId || !clientSecret) {
        return { statusCode: 500, body: 'Missing Strava client credentials' };
      }

      // Exchange code for tokens
      const tokenResp = await fetch('https://www.strava.com/oauth/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          client_id: clientId,
          client_secret: clientSecret,
          code,
          grant_type: 'authorization_code'
        })
      });

      if (!tokenResp.ok) {
        const text = await tokenResp.text();
        console.error('Token exchange failed', text);
        return { statusCode: 502, body: 'Failed to exchange code with Strava' };
      }

      const tokenJson = await tokenResp.json();
      // tokenJson example: { access_token, refresh_token, expires_at, athlete: { id, ... } }
      const athleteId = String((tokenJson.athlete && tokenJson.athlete.id) || tokenJson.athlete_id || tokenJson.athleteId);
      if (!athleteId) {
        console.error('No athlete id in token response', tokenJson);
        return { statusCode: 502, body: 'No athlete id returned from Strava' };
      }

      const item = {
        strava_athlete_id: athleteId,
        access_token: tokenJson.access_token,
        refresh_token: tokenJson.refresh_token,
        expires_at: tokenJson.expires_at,
        created_at: new Date().toISOString()
      };

      const table = process.env.USERS_TABLE;
      if (!table) throw new Error('Missing USERS_TABLE env var');

      await dynamo.put({ TableName: table, Item: item }).promise();

      const frontend = process.env.FRONTEND_URL || '/dashboard';
      return redirectResponse(frontend);
    }

    return { statusCode: 404, body: 'Not found' };
  } catch (err) {
    console.error('Handler error', err);
    return { statusCode: 500, body: 'Internal server error' };
  }
};
