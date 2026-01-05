import json
import os
import jwt  # Requires PyJWT package
import boto3
from botocore.exceptions import ClientError

# Initialize Secrets Manager client
secrets_client = boto3.client('secretsmanager')

# Get secret name from environment variable (set by Terraform)
JWT_SECRET_NAME = os.environ.get('JWT_SECRET_NAME', 'rexai/jwt/secret')

def get_secret(secret_name):
    """
    Retrieve the secret from AWS Secrets Manager.
    """
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        secret_string = response['SecretString']

        try:
            # Parse JSON if stored in JSON format
            secret = json.loads(secret_string)
            # Support both 'secret' (new format) and 'jwtSecret' (legacy format)
            return secret.get('secret') or secret.get('jwtSecret')
        except json.JSONDecodeError:
            # If it's plain text, return as-is
            return secret_string

    except ClientError as e:
        print(f"Failed to retrieve secret '{secret_name}': {str(e)}")
        raise e

def lambda_handler(event, context):
    """
    Lambda Authorizer function to validate JWT from Authorization header.
    """
    print(f"Received event: {json.dumps(event)}")

    # Retrieve JWT secret from Secrets Manager using env variable
    secret_key = get_secret(JWT_SECRET_NAME)
    print(f"Secret key fetched: {secret_key[:5]}... (truncated)")

    # Retrieve headers
    headers = event.get('headers', {})

    # Extract JWT from Authorization header
    auth_header = headers.get("authorization", "")
    # Ensure Authorization header is present
    if not auth_header:
        auth_header = headers.get("Authorization", "")
        if not auth_header:
            print("Authorization header missing")
            return generate_policy('user', 'Deny', event['methodArn'])

    # Handle missing "Bearer " prefix
    if auth_header.startswith("Bearer "):
        token = auth_header[len("Bearer "):]  # Extract token
    else:
        token = auth_header  # Assume raw JWT token

    try:
        # Decode and verify JWT token
        decoded_token = jwt.decode(token, secret_key, algorithms=["HS256"])
        print(f"Decoded JWT: {json.dumps(decoded_token, indent=2)}")

        # Validate required claims
        if 'sub' not in decoded_token:
            print("JWT is missing 'sub' claim")
            return generate_policy('user', 'Deny', event['methodArn'])

        # Return Allow policy if valid
        return generate_policy(decoded_token['sub'], 'Allow', event['methodArn'])

    except jwt.ExpiredSignatureError:
        print("JWT Token has expired")
        return generate_policy('user', 'Deny', event['methodArn'])

    except jwt.InvalidTokenError as e:
        print(f"Invalid JWT Token: {str(e)}")
        return generate_policy('user', 'Deny', event['methodArn'])

    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return generate_policy('user', 'Deny', event['methodArn'])

def generate_policy(principal_id, effect, resource):
    """
    Generate IAM policy for API Gateway authorization.
    """
    print(f"Generating policy: Effect={effect}, Resource={resource}")
    
    try:
        policy_document = {
            'principalId': principal_id,
            'policyDocument': {
                'Version': '2012-10-17',
                'Statement': [{
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': resource
                }]
            }
        }
        return policy_document
    except Exception as e:
        print(f"Error generating policy: {str(e)}")
        return {
            'principalId': 'user',
            'policyDocument': {
                'Version': '2012-10-17',
                'Statement': [{
                    'Action': 'execute-api:Invoke',
                    'Effect': 'Deny',
                    'Resource': '*'
                }]
            }
        }
