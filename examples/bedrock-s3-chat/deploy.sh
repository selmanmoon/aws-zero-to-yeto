#!/bin/bash

# Bedrock + S3 - AI Chatbot (Basit versiyon)
set -e

# AWS CLI pager'ını devre dışı bırakarak script'in takılmasını önle
export AWS_PAGER=""

# Renkli çıktı
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Değişkenler
PROJECT_NAME="bedrock-chat-$(date +%s)"
REGION="us-east-1"
BUCKET_NAME="${PROJECT_NAME}-chats"

print_info "🤖 Bedrock AI Chatbot kuruluyor..."

# 1. S3 Bucket
print_info "📦 S3 bucket oluşturuluyor..."
aws s3 mb s3://$BUCKET_NAME --region $REGION

# 2. Lambda fonksiyonu
print_info "🤖 Lambda fonksiyonu hazırlanıyor..."
cat > lambda_function.py << 'EOF'
import json
import boto3
import uuid
import os
from datetime import datetime

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
s3 = boto3.client('s3')

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        user_message = body.get('message', '')
        
        # Bedrock çağrısı
        model_input = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": [{"role": "user", "content": f"Türkçe yanıtla: {user_message}"}]
        }
        
        response = bedrock.invoke_model(
            body=json.dumps(model_input),
            modelId='anthropic.claude-3-5-sonnet-20240620-v1:0',
            accept='application/json',
            contentType='application/json'
        )
        
        ai_response = json.loads(response.get('body').read())['content'][0]['text']
        
        # S3'e kaydet
        conversation = {
            'id': str(uuid.uuid4()),
            'timestamp': datetime.now().isoformat(),
            'user_message': user_message,
            'ai_response': ai_response
        }
        
        s3.put_object(
            Bucket=os.environ['BUCKET_NAME'],
            Key=f"conversations/{conversation['id']}.json",
            Body=json.dumps(conversation, ensure_ascii=False)
        )
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps(conversation, ensure_ascii=False)
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }
EOF

# Lambda zip
if command -v zip >/dev/null 2>&1; then
    zip lambda_function.zip lambda_function.py
elif command -v 7z >/dev/null 2>&1; then
    7z a -tzip lambda_function.zip lambda_function.py
else
    echo "Hata: zip veya 7z komutu bulunamadı. Lütfen zip veya 7-Zip yükleyin." >&2
    exit 1
fi

# 3. IAM Role
print_info "🔐 IAM role oluşturuluyor..."
cat > trust-policy.json << EOF
{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}
EOF

aws iam create-role --role-name ${PROJECT_NAME}-role --assume-role-policy-document file://trust-policy.json
aws iam attach-role-policy --role-name ${PROJECT_NAME}-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Bedrock ve S3 izinleri
cat > permissions.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow", 
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream"
            ], 
            "Resource": [
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-*",
                "arn:aws:bedrock:*:*:inference-profile/us.anthropic.claude-*",
                "arn:aws:bedrock:*:*:inference-profile/anthropic.claude-*"
            ]
        },
        {
            "Effect": "Allow", 
            "Action": [
                "s3:GetObject", 
                "s3:PutObject"
            ], 
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        }
    ]
}
EOF

aws iam put-role-policy --role-name ${PROJECT_NAME}-role --policy-name BedrockS3Policy --policy-document file://permissions.json

ROLE_ARN=$(aws iam get-role --role-name ${PROJECT_NAME}-role --query 'Role.Arn' --output text)
sleep 10

# 4. Lambda oluştur
print_info "⚡ Lambda fonksiyonu oluşturuluyor..."
LAMBDA_ARN=$(aws lambda create-function \
    --function-name ${PROJECT_NAME}-chatbot \
    --runtime python3.9 \
    --role $ROLE_ARN \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda_function.zip \
    --timeout 30 \
    --environment Variables="{BUCKET_NAME=$BUCKET_NAME}" \
    --region $REGION \
    --query 'FunctionArn' --output text)

# 5. API Gateway
print_info "🌐 API Gateway oluşturuluyor..."
API_ID=$(aws apigateway create-rest-api --name ${PROJECT_NAME}-api --region $REGION --query 'id' --output text)
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION --query 'items[0].id' --output text)

# Chat resource
CHAT_ID=$(aws apigateway create-resource --rest-api-id $API_ID --parent-id $ROOT_ID --path-part chat --region $REGION --query 'id' --output text)

# POST method
aws apigateway put-method --rest-api-id $API_ID --resource-id $CHAT_ID --http-method POST --authorization-type NONE --region $REGION

# Lambda entegrasyon
aws apigateway put-integration \
    --rest-api-id $API_ID --resource-id $CHAT_ID --http-method POST \
    --type AWS_PROXY --integration-http-method POST \
    --uri arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations \
    --region $REGION

# Lambda izni
aws lambda add-permission \
    --function-name ${PROJECT_NAME}-chatbot \
    --principal apigateway.amazonaws.com \
    --action lambda:InvokeFunction \
    --source-arn arn:aws:execute-api:$REGION:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/POST/chat \
    --statement-id api-gateway --region $REGION

# Deploy
aws apigateway create-deployment --rest-api-id $API_ID --stage-name prod --region $REGION

# Sonuçlar
API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/prod"


# Temizlik
rm -f lambda_function.py lambda_function.zip trust-policy.json permissions.json

print_success "🎉 Bedrock AI Chatbot hazır!"
print_info "🤖 API: $API_URL/chat"
print_info "📋 Test: curl -X POST \"$API_URL/chat\" -d '{\"message\":\"Merhaba\"}'"
