# RexAI Extensions Infrastructure - Terraform Module

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Module Updates](#module-updates)
- [Components](#components)
- [Configuration](#configuration)
- [Outputs](#outputs)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [API Documentation](#api-documentation)

## Overview

The RexAI Extensions Infrastructure module provisions the complete application layer for an AI-powered document processing and conversational AI platform on AWS. This module creates:

- **AWS Lambda** functions for document processing and API authorization
- **AWS Step Functions** for orchestrating complex document processing workflows
- **AWS App Runner** services for hosting backend API and frontend applications
- **API Gateway** with JWT authentication for secure API access
- **AWS Cognito** for user authentication with SAML/Okta integration
- **Network Load Balancers** for routing and high availability
- **S3 Storage** for document and artifact management

## Architecture

The infrastructure implements a microservices architecture optimized for AI workloads:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Internet Gateway                               │
└─────────────────┬────────────────────┬──────────────────────────────────┘
                  │                    │
        ┌─────────▼─────────┐ ┌───────▼────────┐
        │   API Gateway     │ │  App Runner    │
        │  (JWT Auth)       │ │   (Frontend)   │
        └─────────┬─────────┘ └────────────────┘
                  │
        ┌─────────▼─────────┐
        │  Lambda Authorizer│
        │    (JWT Valid)    │
        └─────────┬─────────┘
                  │
        ┌─────────▼─────────┐
        │   Internal NLB    │
        └─────────┬─────────┘
                  │
┌─────────────────┼──────────────────────────────────────────────────────┐
│      VPC        │                                                       │
│     ┌───────────▼──────────┐  ┌──────────────┐  ┌─────────────────┐  │
│     │    App Runner        │  │ Step Functions│  │     Lambda      │  │
│     │    (Backend API)     │  │  (Workflow)   │  │  (Processing)   │  │
│     └───────────┬──────────┘  └──────┬───────┘  └────────┬────────┘  │
│                 │                     │                    │           │
│     ┌───────────▼──────────────────────▼──────────────────▼────────┐  │
│     │                    OpenSearch Cluster                        │  │
│     │              (Document Storage & Vector Search)              │  │
│     └───────────────────────────────────────────────────────────────┘  │
│                                                                        │
│     ┌────────────────┐  ┌──────────────┐  ┌────────────────────┐     │
│     │   S3 Bucket    │  │   Secrets    │  │     Cognito        │     │
│     │  (Documents)   │  │   Manager    │  │  (Authentication)  │     │
│     └────────────────┘  └──────────────┘  └────────────────────┘     │
└────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required Infrastructure
Before deploying this module, ensure you have:

1. **Core Infrastructure Module** deployed (`rexai-core-infra-tf`)
   - VPC with public and private subnets
   - OpenSearch cluster
   - ECR repositories

2. **IAM Module** deployed (`rexai-iam-tf`)
   - Required IAM roles and policies
   - Service-linked roles

3. **Container Images** pushed to ECR
   - Lambda processing image
   - Backend API image
   - Frontend application image

### Required Tools
- **Terraform** >= 1.0
- **AWS CLI** configured with appropriate credentials
- **Docker** for building container images
- **Python** 3.9+ for Lambda authorizer

### AWS Permissions
Your AWS credentials need permissions for:
- Lambda function management
- Step Functions state machines
- App Runner services
- API Gateway configuration
- Cognito user pools and identity pools
- S3 bucket operations
- Secrets Manager
- Network Load Balancers
- CloudWatch Logs

## Usage

### Basic Example

```hcl
module "rexai_extensions" {
  source = "./rexai-extensions-infra-tf"

  # Required Core Infrastructure
  vpc_id                = module.core_infra.vpc_id
  private_subnet_ids    = module.core_infra.private_subnet_ids
  public_subnet_ids     = module.core_infra.public_subnet_ids

  # OpenSearch Configuration
  opensearch_endpoint   = module.core_infra.opensearch_endpoint
  opensearch_username   = module.core_infra.opensearch_username
  opensearch_password   = module.core_infra.opensearch_password

  # ECR Repository URLs
  lambda_image_uri      = "${module.core_infra.lambda_ecr_url}:latest"
  backend_image_uri     = "${module.core_infra.backend_ecr_url}:latest"
  frontend_image_uri    = "${module.core_infra.frontend_ecr_url}:latest"

  # IAM Roles
  lambda_role_arn       = module.iam.lambda_role_arn
  stepfunctions_role_arn = module.iam.stepfunctions_role_arn
  apprunner_role_arn    = module.iam.apprunner_role_arn

  # Basic Configuration
  environment           = "production"
  project_name         = "rexai"

  # Cognito Configuration
  cognito_domain       = "rexai-auth"
  allowed_callback_urls = ["https://app.example.com/callback"]
  allowed_logout_urls   = ["https://app.example.com/logout"]
}
```

### Advanced Configuration

```hcl
module "rexai_extensions" {
  source = "./rexai-extensions-infra-tf"

  # Core Infrastructure
  vpc_id                = data.terraform_remote_state.core.outputs.vpc_id
  private_subnet_ids    = data.terraform_remote_state.core.outputs.private_subnet_ids
  public_subnet_ids     = data.terraform_remote_state.core.outputs.public_subnet_ids

  # OpenSearch Configuration
  opensearch_endpoint   = data.terraform_remote_state.core.outputs.opensearch_endpoint
  opensearch_username   = var.opensearch_master_username
  opensearch_password   = data.aws_secretsmanager_secret_version.opensearch.secret_string

  # Container Images with Specific Tags
  lambda_image_uri      = "${var.lambda_ecr_url}:v2.1.0"
  backend_image_uri     = "${var.backend_ecr_url}:v2.1.0"
  frontend_image_uri    = "${var.frontend_ecr_url}:v2.1.0"

  # IAM Configuration
  lambda_role_arn       = data.terraform_remote_state.iam.outputs.lambda_role_arn
  stepfunctions_role_arn = data.terraform_remote_state.iam.outputs.stepfunctions_role_arn
  apprunner_role_arn    = data.terraform_remote_state.iam.outputs.apprunner_role_arn

  # Environment Configuration
  environment           = "production"
  project_name         = "rexai-prod"

  # Lambda Configuration
  lambda_memory_size    = 10240  # 10GB
  lambda_timeout        = 900    # 15 minutes
  lambda_environment_variables = {
    OPENSEARCH_JOBS_INDEX        = "rexai-jobs"
    OPENSEARCH_DOCS_INDEX        = "rexai-documents"
    OPENSEARCH_CONV_INDEX        = "rexai-conversations"
    OPENSEARCH_CHAT_INDEX        = "rexai-chats"
    EMBEDDING_MODEL_ID           = "amazon.titan-embed-text-v1"
    LLM_MODEL_ID                = "anthropic.claude-v2"
    BATCH_SIZE                   = "25"
    CHUNK_SIZE                   = "1000"
    CHUNK_OVERLAP               = "200"
  }

  # App Runner Configuration
  app_runner_cpu        = "2 vCPU"
  app_runner_memory     = "4 GB"
  max_concurrency       = 100
  max_size             = 10
  min_size             = 2

  # API Gateway Configuration
  api_stage_name        = "v1"
  api_throttle_rate_limit = 10000
  api_throttle_burst_limit = 5000
  custom_domain_name    = "api.rexai.example.com"
  certificate_arn      = "arn:aws:acm:us-east-1:xxx:certificate/xxx"

  # Cognito Configuration
  cognito_domain       = "rexai-auth-prod"
  allowed_callback_urls = [
    "https://app.rexai.com/callback",
    "http://localhost:3000/callback"  # For development
  ]
  allowed_logout_urls = [
    "https://app.rexai.com/logout",
    "http://localhost:3000/logout"
  ]

  # SAML/Okta Integration
  enable_saml          = true
  saml_metadata_url    = "https://company.okta.com/app/metadata"
  saml_provider_name   = "Okta"

  # Frontend Configuration
  frontend_domain_name = "app.rexai.com"
  frontend_environment_variables = {
    NEXT_PUBLIC_API_URL           = "https://api.rexai.com"
    NEXT_PUBLIC_COGNITO_REGION    = "us-east-1"
    NEXT_PUBLIC_COGNITO_POOL_ID   = module.rexai_extensions.cognito_user_pool_id
    NEXT_PUBLIC_COGNITO_CLIENT_ID = module.rexai_extensions.cognito_client_id
  }

  # Monitoring
  enable_xray_tracing  = true
  log_retention_days   = 30

  # Tags
  tags = {
    Environment = "production"
    Project     = "RexAI"
    ManagedBy   = "Terraform"
    CostCenter  = "Engineering"
  }
}
```

## Module Updates

### Updating Module Components

1. **Update Container Images**
   ```bash
   # Build and push new Lambda image
   docker build -t lambda-processor ./lambda
   docker tag lambda-processor:latest ${ECR_REPO_URL}:v2.2.0
   docker push ${ECR_REPO_URL}:v2.2.0

   # Update Terraform variable
   terraform plan -var="lambda_image_uri=${ECR_REPO_URL}:v2.2.0"
   terraform apply -var="lambda_image_uri=${ECR_REPO_URL}:v2.2.0"
   ```

2. **Update Step Functions Workflow**
   ```bash
   # Modify step_functions_config.json
   vim step_functions_config.json

   # Apply changes
   terraform apply -target=aws_sfn_state_machine.job_processor
   ```

3. **Update Lambda Authorizer**
   ```bash
   # Modify api-gateway-authorizer.py
   vim api-gateway-authorizer.py

   # Apply changes
   terraform apply -target=aws_lambda_function.api_authorizer
   ```

4. **Rolling Updates for App Runner**
   ```bash
   # App Runner automatically performs rolling updates
   terraform apply -target=aws_apprunner_service.backend
   terraform apply -target=aws_apprunner_service.frontend
   ```

5. **Update API Gateway**
   ```bash
   # Deploy API changes
   terraform apply -target=aws_api_gateway_deployment.main
   ```

### Version Management

```hcl
# versions.tf
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
```

### Dependency Updates

```bash
# Update Terraform providers
terraform init -upgrade

# Lock provider versions
terraform providers lock \
  -platform=linux_amd64 \
  -platform=darwin_amd64 \
  -platform=darwin_arm64

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply updates
terraform apply
```

## Components

### Compute Services

#### AWS Lambda
- **Job Processor**: Handles document processing, indexing, and AI operations
- **API Authorizer**: Validates JWT tokens for API Gateway requests
- Container-based deployment with VPC integration
- Configurable memory (up to 10GB) and timeout (up to 15 minutes)

#### AWS Step Functions
- Orchestrates complex document processing workflows
- Parallel batch processing with concurrency controls
- Built-in error handling and retry logic
- Phases: Save → Index → Process → Execute → Complete

#### AWS App Runner
- **Backend Service**: RESTful API service (private)
- **Frontend Service**: Next.js web application (public)
- Auto-scaling based on concurrent requests
- Health checks and automatic deployments

### API & Authentication

#### API Gateway
- REST API with resource-based routing
- JWT authentication via Lambda authorizer
- VPC Link integration to private backend
- Throttling and usage plans
- Custom domain support

#### AWS Cognito
- User pool for authentication
- Identity pool for AWS credential vending
- SAML integration for enterprise SSO
- Password policies and MFA support
- Custom domains for hosted UI

### Storage & Data

#### S3 Bucket
- Document and artifact storage
- Versioning enabled
- Lifecycle policies for cost optimization
- Server-side encryption

#### Secrets Manager
- JWT secret for API authentication
- Secure credential storage
- Automatic rotation support

### Networking

#### Load Balancers
- **Internal NLB**: Routes API Gateway to App Runner
- **Public NLB**: External OpenSearch access
- Multi-AZ deployment for high availability

#### VPC Integration
- Shared VPC connector for App Runner
- Security groups with least-privilege access
- Private subnet deployment for compute resources

## Configuration

### Required Variables

| Variable | Description | Type | Example |
|----------|-------------|------|---------|
| `vpc_id` | VPC ID for deployment | `string` | `vpc-12345` |
| `private_subnet_ids` | Private subnet IDs | `list(string)` | `["subnet-123", "subnet-456"]` |
| `public_subnet_ids` | Public subnet IDs | `list(string)` | `["subnet-789", "subnet-abc"]` |
| `opensearch_endpoint` | OpenSearch cluster endpoint | `string` | `https://search-domain.region.es.amazonaws.com` |
| `lambda_image_uri` | Lambda container image URI | `string` | `123456789.dkr.ecr.region.amazonaws.com/lambda:latest` |
| `backend_image_uri` | Backend container image URI | `string` | `123456789.dkr.ecr.region.amazonaws.com/backend:latest` |
| `frontend_image_uri` | Frontend container image URI | `string` | `123456789.dkr.ecr.region.amazonaws.com/frontend:latest` |
| `lambda_role_arn` | IAM role ARN for Lambda | `string` | `arn:aws:iam::123456789:role/lambda-role` |

### Optional Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `environment` | Environment name | `string` | `"production"` |
| `lambda_memory_size` | Lambda memory in MB | `number` | `10240` |
| `lambda_timeout` | Lambda timeout in seconds | `number` | `900` |
| `app_runner_cpu` | App Runner CPU configuration | `string` | `"1 vCPU"` |
| `app_runner_memory` | App Runner memory configuration | `string` | `"2 GB"` |
| `max_concurrency` | Max concurrent requests | `number` | `100` |
| `enable_xray_tracing` | Enable X-Ray tracing | `bool` | `false` |
| `log_retention_days` | CloudWatch log retention | `number` | `7` |

## Outputs

| Output | Description | Type |
|--------|-------------|------|
| `api_gateway_url` | API Gateway invoke URL | `string` |
| `frontend_url` | Frontend application URL | `string` |
| `backend_service_arn` | Backend App Runner service ARN | `string` |
| `lambda_function_arn` | Lambda processor function ARN | `string` |
| `step_functions_arn` | Step Functions state machine ARN | `string` |
| `cognito_user_pool_id` | Cognito user pool ID | `string` |
| `cognito_client_id` | Cognito app client ID | `string` |
| `s3_bucket_name` | S3 bucket name | `string` |
| `nlb_dns_name` | Internal NLB DNS name | `string` |

## Maintenance

### Regular Tasks

1. **Update Container Images**
   - Regularly update base images for security patches
   - Test new versions in staging before production
   - Use semantic versioning for image tags

2. **Monitor Performance**
   ```bash
   # Check Lambda metrics
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Lambda \
     --metric-name Duration \
     --dimensions Name=FunctionName,Value=rexai-processor \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-02T00:00:00Z \
     --period 3600 \
     --statistics Average,Maximum

   # Check App Runner metrics
   aws apprunner describe-service \
     --service-arn ${SERVICE_ARN}
   ```

3. **Cost Optimization**
   - Review Lambda invocation patterns
   - Adjust App Runner scaling parameters
   - Implement S3 lifecycle policies
   - Use Reserved Capacity for predictable workloads

4. **Security Updates**
   - Rotate JWT secrets periodically
   - Review API Gateway access logs
   - Update Cognito password policies
   - Audit IAM permissions

### Backup & Disaster Recovery

```bash
# Backup Cognito user pool
aws cognito-idp describe-user-pool \
  --user-pool-id ${USER_POOL_ID} > cognito-backup.json

# Export Step Functions definition
aws stepfunctions describe-state-machine \
  --state-machine-arn ${STATE_MACHINE_ARN} > stepfunctions-backup.json

# Backup S3 bucket
aws s3 sync s3://${BUCKET_NAME} ./backup/
```

## Troubleshooting

### Common Issues

#### Lambda Function Timeouts
```bash
# Check Lambda logs
aws logs tail /aws/lambda/rexai-processor --follow

# Increase timeout
terraform apply -var="lambda_timeout=900"
```

#### App Runner Deployment Failures
```bash
# Check deployment status
aws apprunner list-operations --service-arn ${SERVICE_ARN}

# View deployment logs
aws logs tail /aws/apprunner/${SERVICE_NAME} --follow

# Rollback to previous version
aws apprunner update-service \
  --service-arn ${SERVICE_ARN} \
  --source-configuration '{"ImageRepository":{"ImageIdentifier":"${PREVIOUS_IMAGE}"}}'
```

#### API Gateway 401 Unauthorized
```bash
# Test JWT token
curl -X POST ${API_URL}/test \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -H "Content-Type: application/json"

# Check authorizer logs
aws logs tail /aws/lambda/rexai-authorizer --follow

# Verify JWT secret
aws secretsmanager get-secret-value --secret-id jwt-secret
```

#### Step Functions Execution Failures
```bash
# List recent executions
aws stepfunctions list-executions \
  --state-machine-arn ${STATE_MACHINE_ARN} \
  --status-filter FAILED

# Get execution details
aws stepfunctions describe-execution \
  --execution-arn ${EXECUTION_ARN}

# View execution history
aws stepfunctions get-execution-history \
  --execution-arn ${EXECUTION_ARN}
```

#### Cognito Authentication Issues
```bash
# Check user pool configuration
aws cognito-idp describe-user-pool --user-pool-id ${USER_POOL_ID}

# List user pool clients
aws cognito-idp list-user-pool-clients --user-pool-id ${USER_POOL_ID}

# Check SAML configuration
aws cognito-idp describe-identity-provider \
  --user-pool-id ${USER_POOL_ID} \
  --provider-name ${SAML_PROVIDER}
```

### Debug Commands

```bash
# Test OpenSearch connectivity from Lambda
aws lambda invoke \
  --function-name rexai-processor \
  --payload '{"test": "opensearch_connection"}' \
  response.json

# Check NLB target health
aws elbv2 describe-target-health \
  --target-group-arn ${TARGET_GROUP_ARN}

# Verify VPC connector
aws apprunner describe-vpc-connector \
  --vpc-connector-arn ${VPC_CONNECTOR_ARN}

# Test API endpoint
curl -X GET ${API_GATEWAY_URL}/health
```

## API Documentation

### Authentication

All API requests require a valid JWT token in the Authorization header:

```bash
Authorization: Bearer <jwt_token>
```

### Endpoints

#### POST /jobs
Create a new processing job
```json
{
  "document_url": "s3://bucket/document.pdf",
  "processing_type": "index",
  "parameters": {
    "chunk_size": 1000,
    "overlap": 200
  }
}
```

#### GET /jobs/{job_id}
Get job status
```json
{
  "job_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "processing",
  "progress": 75,
  "created_at": "2024-01-01T00:00:00Z"
}
```

#### POST /chat
Send a chat message
```json
{
  "conversation_id": "conv-123",
  "message": "What is the main topic of the document?",
  "context": ["doc-456", "doc-789"]
}
```

#### GET /documents/{doc_id}
Retrieve document metadata
```json
{
  "document_id": "doc-456",
  "title": "Technical Specification",
  "indexed_at": "2024-01-01T00:00:00Z",
  "chunks": 42
}
```

## Performance Tuning

### Lambda Optimization
```hcl
# Increase memory for better performance
lambda_memory_size = 10240  # Maximum memory

# Configure reserved concurrency
reserved_concurrent_executions = 100

# Enable provisioned concurrency for consistent performance
provisioned_concurrent_executions = 10
```

### App Runner Optimization
```hcl
# Scale configuration
max_concurrency = 200  # Requests per instance
max_size = 25          # Maximum instances
min_size = 2           # Minimum instances

# CPU and Memory
app_runner_cpu = "4 vCPU"
app_runner_memory = "8 GB"
```

### Step Functions Optimization
```json
{
  "MaxConcurrency": 50,
  "RetryStrategy": {
    "MaxAttempts": 3,
    "BackoffRate": 2.0,
    "IntervalSeconds": 2
  }
}
```

## Security Best Practices

1. **API Security**
   - Implement rate limiting at API Gateway
   - Use WAF rules for additional protection
   - Enable API request/response logging
   - Implement API key rotation

2. **Data Protection**
   - Enable S3 bucket encryption
   - Use VPC endpoints for AWS services
   - Implement data retention policies
   - Enable CloudTrail for audit logging

3. **Access Control**
   - Use least-privilege IAM policies
   - Enable MFA for Cognito users
   - Implement IP whitelisting where appropriate
   - Regular access reviews

4. **Network Security**
   - Deploy resources in private subnets
   - Use security groups as virtual firewalls
   - Enable VPC Flow Logs
   - Implement network segmentation

## Cost Optimization

### Recommendations

1. **Compute Optimization**
   - Use Spot instances for batch processing
   - Implement auto-scaling policies
   - Schedule non-production resources
   - Use Lambda Provisioned Concurrency judiciously

2. **Storage Optimization**
   - Implement S3 lifecycle policies
   - Use S3 Intelligent-Tiering
   - Compress data where possible
   - Clean up old CloudWatch logs

3. **Reserved Capacity**
   - Purchase Savings Plans for App Runner
   - Use Reserved Instances for predictable workloads
   - Commit to Compute Savings Plans

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/enhancement`)
3. Make your changes
4. Run validation:
   ```bash
   terraform fmt -recursive
   terraform validate
   tflint
   ```
5. Submit a pull request

## License

This module is maintained by the RexAI team. For internal use only.

## Support

For issues, questions, or feature requests:
- Create an issue in the repository
- Contact the Platform Engineering team
- Review the [AWS Documentation](https://docs.aws.amazon.com/)
- Check the [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Changelog

### Version 2.1.0 (2024-01)
- Added SAML/Okta integration
- Improved Step Functions error handling
- Enhanced monitoring with X-Ray support
- Optimized Lambda cold start performance

### Version 2.0.0 (2023-12)
- Migrated to container-based Lambda
- Added App Runner services
- Implemented JWT authentication
- Added Cognito user management

### Version 1.0.0 (2023-11)
- Initial release
- Basic Lambda processing
- API Gateway integration
- S3 storage setup