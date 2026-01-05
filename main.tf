# ============================================================================
# RexAI Application Module
# ============================================================================
# This module contains all application components that depend on IAM and OpenSearch

# Data sources
data "aws_caller_identity" "current" {}

# ----------------------------------------------------------------------------
# S3 Bucket
# ----------------------------------------------------------------------------
resource "aws_s3_bucket" "rexai_bucket" {
  bucket = var.s3_bucket_name

  tags = merge(
    var.tags,
    {
      Name = var.s3_bucket_name
    }
  )
}

resource "aws_s3_bucket_versioning" "rexai_bucket_versioning" {
  bucket = aws_s3_bucket.rexai_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "rexai_bucket_pab" {
  bucket = aws_s3_bucket.rexai_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----------------------------------------------------------------------------
# JWT Secret for API Gateway
# ----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.name_prefix}/jwt/secret"
  description             = "JWT secret for API Gateway Lambda Authorizer"
  recovery_window_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-jwt-secret"
    }
  )
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    secret = var.jwt_secret_value != "" ? var.jwt_secret_value : random_password.jwt_secret.result
  })
}

resource "random_password" "jwt_secret" {
  length  = 32
  special = true
}

# ----------------------------------------------------------------------------
# Security Groups
# ----------------------------------------------------------------------------
# Lambda Security Group
resource "aws_security_group" "lambda_sg" {
  name        = var.lambda_security_group_name
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = var.lambda_security_group_name
    }
  )
}

# App Runner VPC Connector Security Group - DEPRECATED
# Now using shared VPC connector security group (aws_security_group.shared_vpc_connector_sg)
# Kept for reference only - can be removed in future versions
# resource "aws_security_group" "apprunner_vpc_connect_sg" {
#   name        = "${var.name_prefix}-apprunner-vpc-connect-sg"
#   description = "Security group for App Runner VPC connector"
#   vpc_id      = var.vpc_id
#
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = [var.vpc_cidr_block]
#   }
#
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   lifecycle {
#     ignore_changes = all
#   }
#
#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.name_prefix}-apprunner-vpc-connect-sg"
#     }
#   )
# }


# NLB Security Group
resource "aws_security_group" "nlb_sg" {
  name        = "${var.name_prefix}-nlb-sg"
  description = "Security group for NLB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nlb-sg"
    }
  )
}

# ----------------------------------------------------------------------------
# OpenSearch NLB for Public Access
# ----------------------------------------------------------------------------

# Security Group for OpenSearch NLB
resource "aws_security_group" "opensearch_nlb_sg" {
  name        = "${var.name_prefix}-opensearch-nlb-sg"
  description = "Security group for OpenSearch NLB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.opensearch_nlb_allowed_cidr_blocks
    description = "HTTPS access to OpenSearch"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-opensearch-nlb-sg"
    }
  )
}

# Network Load Balancer for OpenSearch
resource "aws_lb" "opensearch_nlb" {
  name               = "${var.name_prefix}-opensearch-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnets

  enable_deletion_protection       = var.opensearch_nlb_enable_deletion_protection
  enable_cross_zone_load_balancing = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-opensearch-nlb"
    }
  )
}

# Target Group for OpenSearch
resource "aws_lb_target_group" "opensearch_nlb_tg" {
  name        = "${var.name_prefix}-opensearch-nlb-tg"
  port        = 443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    protocol            = "TCP"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-opensearch-nlb-tg"
    }
  )
}

# Register OpenSearch IPs as targets - using variable IPs
resource "aws_lb_target_group_attachment" "opensearch_nlb_targets" {
  count = length(var.opensearch_private_ips)

  target_group_arn = aws_lb_target_group.opensearch_nlb_tg.arn
  target_id        = var.opensearch_private_ips[count.index]
  port             = 443
}

# TCP Listener for OpenSearch NLB
resource "aws_lb_listener" "opensearch_nlb_listener" {
  load_balancer_arn = aws_lb.opensearch_nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.opensearch_nlb_tg.arn
  }
}

# ----------------------------------------------------------------------------
# Backend Role Mapping Configuration for OpenSearch
# ----------------------------------------------------------------------------
locals {
  opensearch_nlb_endpoint = "https://${aws_lb.opensearch_nlb.dns_name}"

  backend_roles = [
    var.app_runner_role_arn,
    var.lambda_execution_role_arn
  ]

  backend_roles_json = jsonencode({
    backend_roles = local.backend_roles
  })
}

resource "null_resource" "opensearch_backend_role_mapping" {
  count = var.configure_opensearch_backend_roles ? 1 : 0

  depends_on = [
    aws_lb.opensearch_nlb,
    aws_lb_listener.opensearch_nlb_listener
  ]

  triggers = {
    backend_roles = local.backend_roles_json
    nlb_endpoint  = local.opensearch_nlb_endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for OpenSearch domain to be ready..."
      sleep 60

      # Configure all_access role mapping
      curl -X PUT "${local.opensearch_nlb_endpoint}/_opendistro/_security/api/rolesmapping/all_access" \
        -u '${var.opensearch_master_username}:${var.opensearch_master_password}' \
        -H 'Content-Type: application/json' \
        -d '{
          "backend_roles": ${jsonencode(local.backend_roles)},
          "hosts": [],
          "users": ["${var.opensearch_master_username}"]
        }' \
        --insecure || echo "Failed to update all_access role mapping"

      # Also map to security_manager role
      curl -X PUT "${local.opensearch_nlb_endpoint}/_opendistro/_security/api/rolesmapping/security_manager" \
        -u '${var.opensearch_master_username}:${var.opensearch_master_password}' \
        -H 'Content-Type: application/json' \
        -d '{
          "backend_roles": ${jsonencode(local.backend_roles)},
          "hosts": [],
          "users": ["${var.opensearch_master_username}"]
        }' \
        --insecure || echo "Failed to update security_manager role mapping"

      echo "Backend role mappings configured successfully"
    EOT
  }
}

# ----------------------------------------------------------------------------
# Lambda Function
# ----------------------------------------------------------------------------
# Force Lambda to update when image URI changes
resource "null_resource" "lambda_image_update" {
  triggers = {
    image_uri = var.lambda_image_uri
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws lambda update-function-code \
        --function-name ${var.lambda_function_name} \
        --image-uri ${var.lambda_image_uri} \
        --region ${var.region} || true
    EOT
  }

  depends_on = [aws_lambda_function.main]
}

resource "aws_lambda_function" "main" {
  function_name = var.lambda_function_name
  role          = var.lambda_execution_role_arn
  package_type  = "Image"
  image_uri     = var.lambda_image_uri
  timeout       = 900
  memory_size   = 10240

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      OPENSEARCH_URL          = "https://${var.opensearch_domain_endpoint}"
      S3_BUCKET               = aws_s3_bucket.rexai_bucket.id
      RECORDS_SCHEDULE_INDEX  = var.records_schedule_index
      JOBS_MASTER_INDEX       = var.jobs_master_index
      JOBS_FILES_INDEX        = var.jobs_files_index
      JOBS_EXECUTE_INDEX      = var.jobs_execute_index
      CHAT_CONVERSATION_INDEX = var.chat_conversation_index
      CLEANUP_STATUS_INDEX    = var.cleanup_status_index
      EMBEDDING_MODEL_ID      = var.embedding_model_id
      LLM_MODEL_ID            = var.llm_model_id
      BATCH_SIZE              = var.batch_size
      EXECUTION_CHUNK_SIZE    = var.execution_chunk_size
      DEFAULT_USER_ID         = var.default_user_id
      MIN_SCORE               = var.min_score
      MIN_MATCHED_TERMS       = var.min_matched_terms
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.lambda_function_name
    }
  )
}

# ----------------------------------------------------------------------------
# Step Function
# ----------------------------------------------------------------------------
resource "aws_sfn_state_machine" "invoke_lambda_step_function" {
  name     = var.step_function_name
  role_arn = var.step_function_role_arn

  definition = var.state_machine_definition_file != "" ? templatefile("${path.module}/${var.state_machine_definition_file}", {
    LambdaFunctionArn = aws_lambda_function.main.arn
    }) : jsonencode({
    Comment = "Step Function to invoke Lambda"
    StartAt = "InvokeLambda"
    States = {
      InvokeLambda = {
        Type     = "Task"
        Resource = aws_lambda_function.main.arn
        End      = true
      }
    }
  })

  tags = merge(
    var.tags,
    {
      Name = var.step_function_name
    }
  )
}

# ----------------------------------------------------------------------------
# App Runner Configuration
# ----------------------------------------------------------------------------
module "app_runner_shared_configs" {
  source = "terraform-aws-modules/app-runner/aws"

  create_service = false

  auto_scaling_configurations = {
    mega = {
      name            = "${var.name_prefix}-mega"
      max_concurrency = 100
      max_size        = 25
      min_size        = 1

      tags = {
        Type = "MEGA"
      }
    }
  }

  tags = var.tags
}

module "app_runner_private" {
  source = "terraform-aws-modules/app-runner/aws"

  service_name = "${var.name_prefix}-backend"

  auto_scaling_configuration_arn = module.app_runner_shared_configs.auto_scaling_configurations["mega"].arn

  instance_configuration = {
    instance_role_arn = var.app_runner_role_arn
    cpu               = "4096"
    memory            = "8192"
  }

  create_instance_iam_role = false

  source_configuration = {
    auto_deployments_enabled = false
    authentication_configuration = {
      access_role_arn = var.apprunner_ecr_access_role_arn
    }
    image_repository = {
      image_identifier      = var.backend_image_uri
      image_repository_type = "ECR"
      image_configuration = {
        port = "8000"
        runtime_environment_variables = {
          AWS_REGION                    = var.region
          AWS_DEFAULT_REGION            = var.region
          AWS_ACCOUNT_ID                = data.aws_caller_identity.current.account_id
          STEP_FUNCTION_NAME            = var.step_function_name
          STEP_FX_ARN                   = aws_sfn_state_machine.invoke_lambda_step_function.arn
          OPENSEARCH_URL                = "https://${var.opensearch_domain_endpoint}"
          S3_BUCKET                     = aws_s3_bucket.rexai_bucket.id
          RECORDS_SCHEDULE_INDEX        = var.records_schedule_index
          JOBS_MASTER_INDEX             = var.jobs_master_index
          JOBS_FILES_INDEX              = var.jobs_files_index
          JOBS_EXECUTE_INDEX            = var.jobs_execute_index
          CHAT_CONVERSATION_INDEX       = var.chat_conversation_index
          CLEANUP_STATUS_INDEX          = var.cleanup_status_index
          EMBEDDING_MODEL_ID            = var.embedding_model_id
          LLM_MODEL_ID                  = var.llm_model_id
          BATCH_SIZE                    = var.batch_size
          EXECUTION_CHUNK_SIZE          = var.execution_chunk_size
          DEFAULT_USER_ID               = var.default_user_id
          MIN_SCORE                     = var.min_score
          MIN_MATCHED_TERMS             = var.min_matched_terms
        }
      }
    }
  }

  create_ingress_vpc_connection = var.create_apprunner_ingress_connection && var.apprunner_endpoint_id != ""
  ingress_vpc_id                = var.vpc_id
  ingress_vpc_endpoint_id       = var.apprunner_endpoint_id != "" ? var.apprunner_endpoint_id : null

  create_vpc_connector = false

  network_configuration = {
    ingress_configuration = {
      is_publicly_accessible = false
    }
    egress_configuration = {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.shared.arn
    }
  }

  tags = var.tags
}

# ----------------------------------------------------------------------------
# NLB for App Runner
# ----------------------------------------------------------------------------
resource "aws_lb" "nlb" {
  name                                                         = "${var.name_prefix}-apigw-to-apprunner-nlb"
  internal                                                     = true
  load_balancer_type                                           = "network"
  subnets                                                      = var.private_subnets
  security_groups                                              = [aws_security_group.nlb_sg.id]
  enforce_security_group_inbound_rules_on_private_link_traffic = "off"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-apigw-to-apprunner-nlb"
    }
  )
}

resource "aws_lb_target_group" "nlb_target_group" {
  name        = "${var.name_prefix}-nlb-target-group"
  port        = 443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nlb-target-group"
    }
  )
}

# ENI data sources moved to OpenSearch module - using variable input instead

resource "aws_lb_target_group_attachment" "targets" {
  count            = length(var.apprunner_private_ips)
  target_group_arn = aws_lb_target_group.nlb_target_group.arn
  target_id        = var.apprunner_private_ips[count.index]
  port             = 443
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_target_group.arn
  }
}

# ----------------------------------------------------------------------------
# API Gateway Lambda Authorizer Function
# ----------------------------------------------------------------------------
resource "aws_lambda_function" "authorizer" {
  function_name    = var.apigw_lambda_function_name
  role             = var.lambda_authorizer_role_arn
  handler          = "api-gateway-authorizer.lambda_handler"
  runtime          = "python3.12"
  filename         = "${path.module}/api-gateway-authorizer.zip"
  source_code_hash = filebase64sha256("${path.module}/api-gateway-authorizer.zip")

  timeout     = 10
  memory_size = 128

  # VPC Configuration
  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      JWT_SECRET_NAME = aws_secretsmanager_secret.jwt_secret.name
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.apigw_lambda_function_name
    }
  )

  depends_on = [var.lambda_authorizer_role_arn] # Ensure role is created before Lambda deploys
}

# Note: The api-gateway-authorizer.zip file should be present in the module directory
# This file contains the Lambda authorizer implementation

# ----------------------------------------------------------------------------
# API Gateway
# ----------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "api" {
  name        = var.api_gateway_name
  description = var.api_gateway_description

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    var.tags,
    {
      Name = var.api_gateway_name
    }
  )
}

resource "aws_api_gateway_authorizer" "lambda_authorizer" {
  name                             = var.lambda_authorizer_name
  rest_api_id                      = aws_api_gateway_rest_api.api.id
  authorizer_uri                   = aws_lambda_function.authorizer.invoke_arn
  type                             = "REQUEST"
  authorizer_result_ttl_in_seconds = 0
  identity_source                  = "method.request.header.Authorization,context.$context.httpMethod,context.$context.resourceId"
  authorizer_credentials           = aws_iam_role.api_gateway_authorizer_role.arn
}

resource "aws_iam_role" "api_gateway_authorizer_role" {
  name = "${var.name_prefix}-api-gateway-authorizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "api_gateway_authorizer_policy" {
  role = aws_iam_role.api_gateway_authorizer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "lambda:InvokeFunction"
      ]
      Effect   = "Allow"
      Resource = aws_lambda_function.authorizer.arn
    }]
  })
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
  request_parameters = {
    "method.request.header.Content-Type" = true
    "method.request.path.proxy"          = true
  }
}

resource "aws_api_gateway_integration" "nlb" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "${module.app_runner_private.service_url}/{proxy}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.nlb.id

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}


resource "aws_api_gateway_vpc_link" "nlb" {
  name        = "${var.name_prefix}-vpc-link"
  target_arns = [aws_lb.nlb.arn]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc-link"
    }
  )
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    # Use specific attributes to avoid unnecessary redeployments from computed field drift
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_resource.proxy.path_part,
      aws_api_gateway_method.proxy.http_method,
      aws_api_gateway_method.proxy.authorization,
      aws_api_gateway_method.proxy.authorizer_id,
      aws_api_gateway_integration.nlb.type,
      aws_api_gateway_integration.nlb.uri,
      aws_api_gateway_integration.nlb.connection_type,
      aws_api_gateway_integration.nlb.connection_id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.api_stage_name

  tags = merge(
    var.tags,
    {
      Name = var.api_stage_name
    }
  )
}

# ----------------------------------------------------------------------------
# API Gateway Custom Domain Configuration
# ----------------------------------------------------------------------------
resource "aws_api_gateway_domain_name" "api" {
  count = var.api_custom_domain != "" && var.certificate_arn != "" ? 1 : 0

  domain_name              = var.api_custom_domain
  regional_certificate_arn = var.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    var.tags,
    {
      Name = var.api_custom_domain
    }
  )
}

resource "aws_api_gateway_base_path_mapping" "api" {
  count = var.api_custom_domain != "" && var.certificate_arn != "" ? 1 : 0

  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api.stage_name
  domain_name = aws_api_gateway_domain_name.api[0].domain_name
}