#!/bin/bash

# Get upload ARN and URL from AWS Device Farm
upload_response=$(aws devicefarm create-upload --project-arn "$1" --name "$2" --type "$3" --output json)
upload_arn=$(echo $upload_response | jq -r '.upload.arn')
upload_url=$(echo $upload_response | jq -r '.upload.url')

# Upload the file
curl -T "$4" "$upload_url"

# Wait for upload to complete
while true; do
  status_response=$(aws devicefarm get-upload --arn "$upload_arn" --output json)
  status=$(echo $status_response | jq -r '.upload.status')
  
  if [ "$status" = "SUCCEEDED" ]; then
    echo "Upload completed successfully"
    echo "$upload_arn"
    break
  elif [ "$status" = "FAILED" ]; then
    message=$(echo $status_response | jq -r '.upload.message')
    echo "Upload failed: $message" >&2
    exit 1
  fi
  
  sleep 5
done
