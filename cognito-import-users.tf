# Actual working Cognito user import implementation

resource "null_resource" "cognito_import_users" {
  count = var.import_cognito_users ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # Create import job
      JOB_RESPONSE=$(aws cognito-idp create-user-import-job \
        --job-name "${var.name_prefix}-import-job-${timestamp()}" \
        --user-pool-id "${aws_cognito_user_pool.rexai.id}" \
        --cloud-watch-logs-role-arn "${var.cognito_cloudwatch_role_arn}" \
        --region "${var.region}" \
        --output json)

      # Extract job ID and pre-signed URL
      JOB_ID=$(echo "$JOB_RESPONSE" | jq -r '.UserImportJob.JobId')
      PRESIGNED_URL=$(echo "$JOB_RESPONSE" | jq -r '.UserImportJob.PreSignedUrl')

      echo "Created import job: $JOB_ID"

      # Upload CSV file to pre-signed URL
      curl -X PUT \
        -H "x-amz-server-side-encryption: aws:kms" \
        -T "${var.cognito_users_csv_path}" \
        "$PRESIGNED_URL"

      echo "Uploaded CSV file"

      # Start the import job
      aws cognito-idp start-user-import-job \
        --user-pool-id "${aws_cognito_user_pool.rexai.id}" \
        --job-id "$JOB_ID" \
        --region "${var.region}"

      echo "Started import job: $JOB_ID"

      # Wait for completion (optional)
      echo "Waiting for import to complete..."
      while true; do
        STATUS=$(aws cognito-idp describe-user-import-job \
          --user-pool-id "${aws_cognito_user_pool.rexai.id}" \
          --job-id "$JOB_ID" \
          --region "${var.region}" \
          --query 'UserImportJob.Status' \
          --output text)

        echo "Import status: $STATUS"

        if [[ "$STATUS" == "Succeeded" ]]; then
          echo "Import completed successfully!"
          break
        elif [[ "$STATUS" == "Failed" ]] || [[ "$STATUS" == "Stopped" ]]; then
          echo "Import failed with status: $STATUS"
          exit 1
        fi

        sleep 10
      done
    EOT

    interpreter = ["bash", "-c"]
  }

  depends_on = [
    aws_cognito_user_pool.rexai,
    aws_iam_role_policy_attachment.cognito_cloudwatch
  ]

  # Force recreation if CSV changes
  triggers = {
    csv_hash = filemd5(var.cognito_users_csv_path)
  }
}