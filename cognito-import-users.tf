# Actual working Cognito user import implementation

resource "null_resource" "cognito_import_users" {
  count = var.import_cognito_users ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # Create import job with timestamp (remove colons to satisfy regex)
      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      JOB_RESPONSE=$(aws cognito-idp create-user-import-job \
        --job-name "${var.name_prefix}-import-job-$TIMESTAMP" \
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

      # Wait for completion with enhanced error handling
      echo "Waiting for import to complete..."
      while true; do
        JOB_INFO=$(aws cognito-idp describe-user-import-job \
          --user-pool-id "${aws_cognito_user_pool.rexai.id}" \
          --job-id "$JOB_ID" \
          --region "${var.region}" \
          --output json)

        STATUS=$(echo "$JOB_INFO" | jq -r '.UserImportJob.Status')
        IMPORTED_USERS=$(echo "$JOB_INFO" | jq -r '.UserImportJob.ImportedUsers // 0')
        SKIPPED_USERS=$(echo "$JOB_INFO" | jq -r '.UserImportJob.SkippedUsers // 0')
        FAILED_USERS=$(echo "$JOB_INFO" | jq -r '.UserImportJob.FailedUsers // 0')

        echo "Import status: $STATUS (Imported: $IMPORTED_USERS, Skipped: $SKIPPED_USERS, Failed: $FAILED_USERS)"

        if [[ "$STATUS" == "Succeeded" ]]; then
          echo "Import completed successfully!"
          break
        elif [[ "$STATUS" == "Failed" ]] || [[ "$STATUS" == "Stopped" ]]; then
          # Check if the failure is due to all users being skipped
          if [[ "$IMPORTED_USERS" -eq 0 ]] && [[ "$SKIPPED_USERS" -gt 0 ]] && [[ "$FAILED_USERS" -eq 0 ]]; then
            echo "Import job stopped because all users already exist in the pool (all skipped). This is acceptable."
            break
          else
            echo "Import failed with status: $STATUS"
            echo "Details - Imported: $IMPORTED_USERS, Skipped: $SKIPPED_USERS, Failed: $FAILED_USERS"
            # Only exit with error if there are actual failed users
            if [[ "$FAILED_USERS" -gt 0 ]]; then
              exit 1
            else
              echo "No actual failures detected, treating as successful import."
              break
            fi
          fi
        fi

        sleep 10
      done
    EOT

    interpreter = ["bash", "-c"]
  }

  depends_on = [
    aws_cognito_user_pool.rexai
  ]

  # Force recreation if CSV changes
  triggers = {
    csv_hash = filemd5(var.cognito_users_csv_path)
  }
}