# ============================================================================
# Cognito Resources for RexAI Application
# ============================================================================
# This module creates AWS Cognito resources including User Pool, Identity Pool,
# App Client, and related IAM roles

# ----------------------------------------------------------------------------
# Cognito User Pool
# ----------------------------------------------------------------------------
resource "aws_cognito_user_pool" "rexai" {
  name = "${var.name_prefix}-userpool"

  # Username attributes - allow sign-in with email
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length    = var.cognito_password_minimum_length
    require_uppercase = var.cognito_password_require_uppercase
    require_lowercase = var.cognito_password_require_lowercase
    require_numbers   = var.cognito_password_require_numbers
    require_symbols   = var.cognito_password_require_symbols
  }

  # Account recovery settings
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # MFA Configuration
  mfa_configuration = var.cognito_mfa_configuration

  # Schema attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 0
      max_length = 256
    }
  }

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Cognito User Pool Domain
# ----------------------------------------------------------------------------
resource "aws_cognito_user_pool_domain" "rexai" {
  domain       = "${var.name_prefix}-domain-${random_string.cognito_domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.rexai.id
}

resource "random_string" "cognito_domain_suffix" {
  length  = 6
  special = false
  upper   = false
}

# ----------------------------------------------------------------------------
# Cognito User Pool Client
# ----------------------------------------------------------------------------
resource "aws_cognito_user_pool_client" "rexai" {
  name         = "${var.name_prefix}-app-client"
  user_pool_id = aws_cognito_user_pool.rexai.id

  # OAuth settings
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["openid", "email", "phone", "profile"]

  # Callback and logout URLs
  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  # Identity providers
  supported_identity_providers = concat(
    ["COGNITO"],
    var.enable_saml_provider ? [aws_cognito_identity_provider.okta[0].provider_name] : []
  )

  # Prevent client secret generation for public clients
  generate_secret = false

  # Token validity
  refresh_token_validity = var.cognito_refresh_token_validity
  access_token_validity  = var.cognito_access_token_validity
  id_token_validity      = var.cognito_id_token_validity

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  depends_on = [
    aws_cognito_identity_provider.okta
  ]
}

# ----------------------------------------------------------------------------
# SAML Identity Provider (Okta)
# ----------------------------------------------------------------------------
resource "aws_cognito_identity_provider" "okta" {
  count = var.enable_saml_provider ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.rexai.id
  provider_name = "${var.name_prefix}-okta-provider"
  provider_type = "SAML"

  provider_details = {
    MetadataURL = var.saml_metadata_url
  }

  attribute_mapping = {
    email = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
  }
}


# ----------------------------------------------------------------------------
# Cognito Identity Pool
# ----------------------------------------------------------------------------
resource "aws_cognito_identity_pool" "rexai" {
  identity_pool_name               = "${var.name_prefix}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.rexai.id
    provider_name           = "cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.rexai.id}"
    server_side_token_check = false
  }

  tags = var.tags
}


# ----------------------------------------------------------------------------
# Attach roles to Identity Pool
# ----------------------------------------------------------------------------
resource "aws_cognito_identity_pool_roles_attachment" "rexai" {
  identity_pool_id = aws_cognito_identity_pool.rexai.id

  roles = {
    "authenticated" = var.cognito_authenticated_role_arn
  }

  role_mapping {
    identity_provider         = "cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.rexai.id}:${aws_cognito_user_pool_client.rexai.id}"
    ambiguous_role_resolution = "AuthenticatedRole"
    type                      = "Token"
  }
}

# ----------------------------------------------------------------------------
# Cognito User Import Job (Optional)
# ----------------------------------------------------------------------------
# Note: Terraform doesn't directly support user import jobs.
# Users can be imported using a null_resource with local-exec or
# managed separately through AWS CLI/Console after infrastructure creation.

resource "null_resource" "cognito_import_users_notification" {
  count = var.import_cognito_users ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "=============================================="
      echo "COGNITO USER IMPORT INFORMATION"
      echo "=============================================="
      echo "User import must be handled through AWS Console or CLI"
      echo ""
      echo "User Pool ID: ${aws_cognito_user_pool.rexai.id}"
      echo "CloudWatch Role ARN: ${var.cognito_cloudwatch_role_arn}"
      echo "CSV file path: ${var.cognito_users_csv_path}"
      echo ""
      echo "To import users via AWS CLI:"
      echo "1. Create import job:"
      echo "   aws cognito-idp create-user-import-job \\"
      echo "     --job-name '${var.name_prefix}-import-job' \\"
      echo "     --user-pool-id '${aws_cognito_user_pool.rexai.id}' \\"
      echo "     --cloud-watch-logs-role-arn '${var.cognito_cloudwatch_role_arn}'"
      echo ""
      echo "2. Upload CSV to the pre-signed URL returned"
      echo "3. Start the import job with the JobId returned"
      echo "=============================================="
    EOT
  }

  depends_on = [
    aws_cognito_user_pool.rexai
  ]
}