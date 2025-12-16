#!/bin/bash

# Renkler
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Benzersiz ID üret
UNIQUE_ID=$(date +%s)
REGION="us-east-1"
BUCKET_NAME="mcp-demo-bucket-$UNIQUE_ID"
TABLE_NAME="mcp-demo-table-$UNIQUE_ID"
FUNCTION_NAME="mcp-demo-function-$UNIQUE_ID"
ROLE_NAME="mcp-demo-role-$UNIQUE_ID"

echo -e "${BLUE}🚀 MCP Demo Ortamı Hazırlanıyor...${NC}"

# 1. S3 Bucket Oluşturma
echo "📦 S3 Bucket oluşturuluyor: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME --region $REGION

# Örnek dosya yükle
echo "Hello MCP!" > hello.txt
aws s3 cp hello.txt s3://$BUCKET_NAME/hello.txt
rm hello.txt

# 2. DynamoDB Tablo Oluşturma
echo "🗄️  DynamoDB Tablo oluşturuluyor: $TABLE_NAME"
aws dynamodb create-table \
    --table-name $TABLE_NAME \
    --attribute-definitions AttributeName=Id,AttributeType=S \
    --key-schema AttributeName=Id,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region $REGION > /dev/null

# 3. Lambda Fonksiyonu Oluşturma
echo "⚡ Lambda Fonksiyonu hazırlanıyor..."

# Role oluştur
TRUST_POLICY='{
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
}'
echo $TRUST_POLICY > trust-policy.json

aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json > /dev/null
rm trust-policy.json

# Role'ün aktif olması için biraz bekle
sleep 10

# Lambda kodu
echo "def lambda_handler(event, context): return 'Hello from MCP!'" > lambda_function.py
zip function.zip lambda_function.py > /dev/null

# Fonksiyonu oluştur
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime python3.9 \
    --role $ROLE_ARN \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --region $REGION > /dev/null

# Temizlik
rm lambda_function.py function.zip

# Kaynak ID'lerini kaydet (Cleanup için)
echo "BUCKET_NAME=$BUCKET_NAME" > .env.demo
echo "TABLE_NAME=$TABLE_NAME" >> .env.demo
echo "FUNCTION_NAME=$FUNCTION_NAME" >> .env.demo
echo "ROLE_NAME=$ROLE_NAME" >> .env.demo
echo "REGION=$REGION" >> .env.demo

echo -e "${GREEN}✅ Kurulum Tamamlandı!${NC}"
echo -e "Aşağıdaki kaynaklar Claude'un incelemesi için hazır:"
echo " - S3: $BUCKET_NAME"
echo " - DynamoDB: $TABLE_NAME"
echo " - Lambda: $FUNCTION_NAME"
