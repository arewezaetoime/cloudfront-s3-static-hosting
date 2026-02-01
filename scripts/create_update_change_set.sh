#!/bin/bash

STACK_NAME="devops-hristoiliev-stack"
TEMPLATE="cloudfront_s3_stack_conf.yml"
REGION="eu-central-1"
BUCKET="devops-hometask-hristoiliev-eu-central-1"


if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION 2>/dev/null; then
    
    # Stack exists - use change set to preview, then update
    CHANGESET_NAME="update-$(date +%Y%m%d%H%M%S)"
    
    aws cloudformation create-change-set \
      --stack-name $STACK_NAME \
      --change-set-name $CHANGESET_NAME \
      --template-body file://$TEMPLATE \
      --region $REGION

    # preview the changes
    aws cloudformation describe-change-set \
      --stack-name $STACK_NAME \
      --change-set-name $CHANGESET_NAME \
      --region $REGION

    CHANGESET_STATUS=$(aws cloudformation describe-change-set \
      --stack-name $STACK_NAME \
      --change-set-name $CHANGESET_NAME \
      --region $REGION \
      --query 'Status' \
      --output text)

    if [ "$CHANGESET_STATUS" == "CREATE_COMPLETE" ]; then
        
        # update
        aws cloudformation execute-change-set \
          --stack-name $STACK_NAME \
          --change-set-name $CHANGESET_NAME \
          --region $REGION

        aws cloudformation wait stack-update-complete \
          --stack-name $STACK_NAME \
          --region $REGION
    else
        echo ""
        echo "No changes detected. Stack is up to date"
    fi

else
    
    # Stack does not exist 
    echo "Stack does not exist. Creating new stack..."
    
    aws cloudformation create-stack \
      --stack-name $STACK_NAME \
      --template-body file://$TEMPLATE \
      --region $REGION

    aws cloudformation wait stack-create-complete \
      --stack-name $STACK_NAME \
      --region $REGION
fi

aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].StackStatus' \
  --output text

# We want to upload index.html only if the file has changed or if it's the first time we deploy the stack
LOCAL_HASH=$(md5sum index.html | awk '{print $1}')
REMOTE_HASH=$(aws s3api head-object \
  --bucket $BUCKET \
  --key index.html \
  --query 'Metadata.md5' \
  --output text 2>/dev/null)

if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
    echo  "index.html is changed. Uploading the new one."
    aws s3 cp index.html s3://$BUCKET/index.html \
      --metadata md5=$LOCAL_HASH
else
    echo "index.html unchanged. Skipping upload."
fi

#verify the upload
echo "Checking if the file is uploaded. ls"
aws s3 ls s3://$BUCKET/

echo "Stack $STACK_NAME has completed successfully"