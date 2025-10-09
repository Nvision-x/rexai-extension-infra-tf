# ============================================================================
# Frontend App Runner Service Configuration
# ============================================================================
# This file creates the App Runner service for the frontend application
# using the same module as backend for consistency

# ----------------------------------------------------------------------------
# Frontend App Runner Service using Module
# ----------------------------------------------------------------------------
module "app_runner_frontend" {
  source = "terraform-aws-modules/app-runner/aws"

  service_name = "${var.name_prefix}-frontend"

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.frontend.arn

  instance_configuration = {
    instance_role_arn = var.frontend_apprunner_instance_role_arn
    cpu               = var.frontend_cpu
    memory            = var.frontend_memory
  }

  create_instance_iam_role = false

  source_configuration = {
    auto_deployments_enabled = var.frontend_auto_deployments_enabled
    authentication_configuration = {
      access_role_arn = var.apprunner_ecr_access_role_arn
    }
    image_repository = {
      image_identifier      = var.frontend_image_uri
      image_repository_type = "ECR"
      image_configuration = {
        port          = "3000"
        start_command = "npm run start"
        runtime_environment_variables = {
          NEXT_PUBLIC_BASE_URL                    = "${module.app_runner_private.service_url}"
          NEXT_PUBLIC_OKTA_SIGNIN_REDIRECT_URI    = var.frontend_okta_redirect_uri
          NEXT_PUBLIC_AWS_USER_POOL_ID            = aws_cognito_user_pool.rexai.id
          NEXT_PUBLIC_AWS_USER_POOL_WEB_CLIENT_ID = aws_cognito_user_pool_client.rexai.id
          NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID    = aws_cognito_identity_pool.rexai.id
          NEXT_PUBLIC_COGNITO_DOMAIN              = "${aws_cognito_user_pool_domain.rexai.domain}.auth.${var.region}.amazoncognito.com"
          NEXT_PUBLIC_OKTA_IDP_NAME               = var.enable_saml_provider ? aws_cognito_identity_provider.okta[0].provider_name : ""
          NEXT_PUBLIC_COGNITO_REGION              = var.region
        }
        runtime_environment_secrets = {
          NEXT_PUBLIC_SECRET_KEY = aws_secretsmanager_secret.jwt_secret.arn
        }
      }
    }
  }

  health_check_configuration = {
    protocol            = "HTTP"
    path                = var.frontend_health_check_path
    interval            = var.frontend_health_check_interval
    timeout             = var.frontend_health_check_timeout
    healthy_threshold   = var.frontend_health_check_healthy_threshold
    unhealthy_threshold = var.frontend_health_check_unhealthy_threshold
  }

  create_vpc_connector = false

  network_configuration = {
    ingress_configuration = {
      is_publicly_accessible = true
    }
    egress_configuration = {
      egress_type       = var.frontend_enable_vpc_connector ? "VPC" : "DEFAULT"
      vpc_connector_arn = var.frontend_enable_vpc_connector ? aws_apprunner_vpc_connector.shared.arn : null
    }
  }

  observability_configuration = {
    observability_enabled           = var.frontend_observability_enabled
    observability_configuration_arn = var.frontend_observability_enabled ? aws_apprunner_observability_configuration.frontend[0].arn : null
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name_prefix}-frontend"
      Component   = "Frontend"
      Runtime     = "nodejs18"
      ServiceType = "AppRunner"
    }
  )

  depends_on = [
    aws_cognito_user_pool.rexai,
    aws_cognito_user_pool_client.rexai,
    aws_cognito_identity_pool.rexai,
    aws_cognito_user_pool_domain.rexai,
    aws_apprunner_vpc_connector.shared
  ]
}

# ----------------------------------------------------------------------------
# Auto Scaling Configuration for Frontend
# ----------------------------------------------------------------------------
resource "aws_apprunner_auto_scaling_configuration_version" "frontend" {
  auto_scaling_configuration_name = "${var.name_prefix}-frontend-autoscaling"

  max_concurrency = var.frontend_max_concurrency
  max_size        = var.frontend_max_size
  min_size        = var.frontend_min_size

  tags = merge(
    var.tags,
    {
      Name      = "${var.name_prefix}-frontend-autoscaling"
      Component = "Frontend"
    }
  )
}


# ----------------------------------------------------------------------------
# Observability Configuration for Frontend (Optional)
# ----------------------------------------------------------------------------
resource "aws_apprunner_observability_configuration" "frontend" {
  count = var.frontend_observability_enabled ? 1 : 0

  observability_configuration_name = "${var.name_prefix}-frontend-observability"

  trace_configuration {
    vendor = "AWSXRAY"
  }

  tags = merge(
    var.tags,
    {
      Name      = "${var.name_prefix}-frontend-observability"
      Component = "Frontend"
    }
  )
}

# ----------------------------------------------------------------------------
# Custom Domain Association (Optional)
# ----------------------------------------------------------------------------
resource "aws_apprunner_custom_domain_association" "frontend" {
  count = var.frontend_custom_domain != "" ? 1 : 0

  domain_name = var.frontend_custom_domain
  service_arn = module.app_runner_frontend.service_arn

  enable_www_subdomain = var.frontend_enable_www_subdomain
}

# ----------------------------------------------------------------------------
# CloudWatch Log Group for Frontend
# ----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "frontend_apprunner" {
  name              = "/aws/apprunner/${var.name_prefix}-frontend"
  retention_in_days = var.frontend_log_retention_days

  tags = merge(
    var.tags,
    {
      Name      = "/aws/apprunner/${var.name_prefix}-frontend"
      Component = "Frontend"
    }
  )
}

