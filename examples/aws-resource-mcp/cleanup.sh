#!/bin/bash

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [ ! -f .env.demo ]; then
    echo -e "${RED}❌ .env.demo dosyası bulunamadı! Önce deploy.sh çalıştırılmalı.${NC}"
    exit 1
fi

source .env.demo

echo -e "${RED}🗑️  Kaynaklar siliniyor...${NC}"

# 1. S3 Sil
echo " - Bucket siliniyor: $BUCKET_NAME"
aws s3 rb s3://$BUCKET_NAME --force

# 2. DynamoDB Sil
echo " - Tablo siliniyor: $TABLE_NAME"
aws dynamodb delete-table --table-name $TABLE_NAME --region $REGION > /dev/null

# 3. Lambda Sil
echo " - Fonksiyon siliniyor: $FUNCTION_NAME"
aws lambda delete-function --function-name $FUNCTION_NAME --region $REGION > /dev/null

# 4. Role Sil
echo " - IAM Role siliniyor: $ROLE_NAME"
aws iam delete-role --role-name $ROLE_NAME > /dev/null

# Dosya temizliği
rm .env.demo

echo -e "${GREEN}✅ Temizlik Tamamlandı!${NC}"
