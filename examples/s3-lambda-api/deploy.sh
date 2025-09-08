#!/bin/bash

# S3 + Lambda + API Gateway - Serverless File Processing
# Bu script basit bir serverless dosya işleme sistemi kurar

set -e

# Renkli çıktı
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Değişkenler
PROJECT_NAME="s3-lambda-api-$(date +%s)"
REGION="eu-west-1"
BUCKET_NAME="${PROJECT_NAME}-files"
LAMBDA_FUNCTION="s3-file-processor"
API_NAME="${PROJECT_NAME}-api"
TABLE_NAME="${PROJECT_NAME}-files"

print_info "🚀 Serverless File Processing sistemi kuruluyor..."
print_info "Proje: $PROJECT_NAME"
print_info "Bucket: $BUCKET_NAME"
print_info "Bölge: $REGION"

# 1. S3 Bucket oluştur
print_info "📦 S3 bucket oluşturuluyor..."
aws s3 mb s3://$BUCKET_NAME --region $REGION
aws s3api put-bucket-notification-configuration --bucket $BUCKET_NAME --notification-configuration '{}'
print_success "S3 bucket oluşturuldu: $BUCKET_NAME"

# 2. DynamoDB tablosu oluştur
print_info "🗄️ DynamoDB tablosu oluşturuluyor..."
aws dynamodb create-table \
    --table-name $TABLE_NAME \
    --attribute-definitions \
        AttributeName=file_id,AttributeType=S \
    --key-schema \
        AttributeName=file_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION

# Lambda fonksiyonu için Python kodu
cat > lambda_function.py << 'EOF'
import json
import boto3
import urllib.parse
from datetime import datetime
import os

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

def lambda_handler(event, context):
    table_name = os.environ['TABLE_NAME']
    table = dynamodb.Table(table_name)
    
    try:
        # S3 event'i parse et
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = urllib.parse.unquote_plus(record['s3']['object']['key'])
            
            print(f"Processing file: {key} from bucket: {bucket}")
            
            # Dosya bilgilerini al
            obj = s3.head_object(Bucket=bucket, Key=key)
            file_size = obj['ContentLength']
            
            # DynamoDB'ye kaydet
            table.put_item(
                Item={
                    'file_id': key,
                    'bucket': bucket,
                    'size': file_size,
                    'processed_at': datetime.now().isoformat(),
                    'status': 'processed'
                }
            )
            
            print(f"File processed successfully: {key}")
    
    except Exception as e:
        print(f"Error processing file: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Files processed successfully'})
    }
EOF

# API Lambda fonksiyonu
cat > api_function.py << 'EOF'
import json
import boto3
import os
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')

def decimal_default(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError

def lambda_handler(event, context):
    table_name = os.environ['TABLE_NAME']
    table = dynamodb.Table(table_name)
    
    try:
        # HTTP method'a göre işlem yap
        http_method = event['httpMethod']
        
        if http_method == 'GET':
            # Tüm dosyaları listele
            response = table.scan()
            items = response['Items']
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'files': items,
                    'count': len(items)
                }, default=decimal_default)
            }
        
        elif http_method == 'POST':
            # Yeni dosya bilgisi ekle
            body = json.loads(event['body'])
            
            table.put_item(Item=body)
            
            return {
                'statusCode': 201,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'message': 'File info saved'})
            }
        
        else:
            return {
                'statusCode': 405,
                'body': json.dumps({'error': 'Method not allowed'})
            }
    
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }
EOF

# Lambda zip dosyaları oluştur
print_info "📝 Lambda fonksiyonları hazırlanıyor..."
zip lambda_function.zip lambda_function.py
zip api_function.zip api_function.py

# IAM role oluştur
print_info "🔐 IAM role oluşturuluyor..."
cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
    --role-name ${PROJECT_NAME}-lambda-role \
    --assume-role-policy-document file://trust-policy.json

# Lambda execution policy ekle
aws iam attach-role-policy \
    --role-name ${PROJECT_NAME}-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# S3 ve DynamoDB izinleri
cat > lambda-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:HeadObject"
            ],
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query"
            ],
            "Resource": "arn:aws:dynamodb:${REGION}:*:table/${TABLE_NAME}"
        }
    ]
}
EOF

aws iam put-role-policy \
    --role-name ${PROJECT_NAME}-lambda-role \
    --policy-name ${PROJECT_NAME}-lambda-policy \
    --policy-document file://lambda-policy.json

# Role ARN'ı al
ROLE_ARN=$(aws iam get-role --role-name ${PROJECT_NAME}-lambda-role --query 'Role.Arn' --output text)

print_info "⏳ IAM role propagation için 10 saniye bekleniyor..."
sleep 10

# S3 processor Lambda fonksiyonu oluştur
print_info "⚡ S3 processor Lambda fonksiyonu oluşturuluyor..."
aws lambda create-function \
    --function-name $LAMBDA_FUNCTION \
    --runtime python3.9 \
    --role $ROLE_ARN \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda_function.zip \
    --environment Variables="{TABLE_NAME=${TABLE_NAME}}" \
    --region $REGION

# API Lambda fonksiyonu oluştur
API_FUNCTION="${PROJECT_NAME}-api"
print_info "📡 API Lambda fonksiyonu oluşturuluyor..."
aws lambda create-function \
    --function-name $API_FUNCTION \
    --runtime python3.9 \
    --role $ROLE_ARN \
    --handler api_function.lambda_handler \
    --zip-file fileb://api_function.zip \
    --environment Variables="{TABLE_NAME=${TABLE_NAME}}" \
    --region $REGION

# S3 bucket notification ekle
print_info "🔔 S3 bucket notification ayarlanıyor..."
LAMBDA_ARN=$(aws lambda get-function --function-name $LAMBDA_FUNCTION --region $REGION --query 'Configuration.FunctionArn' --output text)

# Lambda'ya S3 invoke izni ver
aws lambda add-permission \
    --function-name $LAMBDA_FUNCTION \
    --principal s3.amazonaws.com \
    --action lambda:InvokeFunction \
    --source-arn arn:aws:s3:::$BUCKET_NAME \
    --statement-id s3-trigger \
    --region $REGION

# S3 notification configuration
cat > notification.json << EOF
{
    "LambdaFunctionConfigurations": [
        {
            "Id": "ObjectCreated",
            "LambdaFunctionArn": "$LAMBDA_ARN",
            "Events": ["s3:ObjectCreated:*"],
            "Filter": {
                "Key": {
                    "FilterRules": [
                        {
                            "Name": "prefix",
                            "Value": "uploads/"
                        }
                    ]
                }
            }
        }
    ]
}
EOF

aws s3api put-bucket-notification-configuration \
    --bucket $BUCKET_NAME \
    --notification-configuration file://notification.json

# API Gateway oluştur
print_info "🌐 API Gateway oluşturuluyor..."
API_ID=$(aws apigateway create-rest-api \
    --name $API_NAME \
    --region $REGION \
    --query 'id' --output text)

# Root resource ID'yi al
ROOT_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region $REGION \
    --query 'items[0].id' --output text)

# /files resource oluştur
RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part files \
    --region $REGION \
    --query 'id' --output text)

# GET method ekle
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method GET \
    --authorization-type NONE \
    --region $REGION

# Lambda entegrasyonu
API_LAMBDA_ARN=$(aws lambda get-function --function-name $API_FUNCTION --region $REGION --query 'Configuration.FunctionArn' --output text)

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$API_LAMBDA_ARN/invocations \
    --region $REGION

# Lambda'ya API Gateway izni ver
aws lambda add-permission \
    --function-name $API_FUNCTION \
    --principal apigateway.amazonaws.com \
    --action lambda:InvokeFunction \
    --source-arn "arn:aws:execute-api:$REGION:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/GET/files" \
    --statement-id api-gateway-get \
    --region $REGION

# API'yi deploy et
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region $REGION

# Test dosyası oluştur
print_info "📝 Test dosyası hazırlanıyor..."
echo "Bu bir test dosyasıdır - AWS ZERO to YETO" > test-file.txt
mkdir -p uploads
mv test-file.txt uploads/

# Deployment bilgilerini kaydet
API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/prod"


# Temizlik
rm -f lambda_function.py api_function.py
rm -f lambda_function.zip api_function.zip
rm -f trust-policy.json lambda-policy.json notification.json

print_success "🎉 Serverless File Processing sistemi hazır!"
print_info "📍 API URL: $API_URL/files"
print_info "📦 S3 Bucket: s3://$BUCKET_NAME"
print_info "📋 Test için: aws s3 cp uploads/test-file.txt s3://$BUCKET_NAME/uploads/"
