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
      --region $REGION | cat

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

echo "Stack $STACK_NAME has completed successfully"