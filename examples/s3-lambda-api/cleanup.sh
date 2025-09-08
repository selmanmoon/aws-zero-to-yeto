#!/bin/bash

# AWS ZERO to YETO - S3 Lambda API Temizlik
# Bu script deploy.sh ile yaratılan kaynakları siler

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Konfigürasyon
REGION="eu-west-1"

print_info "🧹 AWS ZERO to YETO - S3 Lambda API Temizleniyor"
print_info "📍 Region: $REGION"

# En son deploy edilen kaynakları bul (timestamp'a göre en yüksek)
print_info "🔍 En son deploy edilen kaynakları aranıyor..."

# En yüksek timestamp'li kaynakları bul
LATEST_TIMESTAMP=$(aws s3 ls | grep "s3-lambda-api-.*-files" | awk '{print $3}' | sed 's/s3-lambda-api-\([0-9]*\)-files/\1/' | sort -n | tail -1)

if [ -z "$LATEST_TIMESTAMP" ]; then
    print_warning "S3 Lambda API kaynakları bulunamadı"
    exit 0
fi

PROJECT_NAME="s3-lambda-api-${LATEST_TIMESTAMP}"
BUCKET_NAME="${PROJECT_NAME}-files"
LAMBDA_FUNCTION="s3-file-processor"  # Bu sabit isim
API_LAMBDA_FUNCTION="${PROJECT_NAME}-api"
ROLE_NAME="${PROJECT_NAME}-role"

print_info "🎯 Hedef kaynaklar:"
print_info "   - S3 Bucket: $BUCKET_NAME"
print_info "   - Lambda Functions: $LAMBDA_FUNCTION, $API_LAMBDA_FUNCTION"
print_info "   - IAM Role: $ROLE_NAME"
print_info "   - API Gateway: $API_LAMBDA_FUNCTION"

echo ""
print_warning "⚠️  Bu kaynaklar silinecek!"
read -p "Devam etmek istiyor musunuz? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_info "İşlem iptal edildi"
    exit 0
fi

echo ""
print_info "🗑️  Kaynaklar siliniyor..."

# 1. API Gateway Sil
print_info "🌐 API Gateway siliniyor: $API_LAMBDA_FUNCTION"
API_ID=$(aws apigateway get-rest-apis --region $REGION --query "items[?name=='$API_LAMBDA_FUNCTION'].id" --output text)
if [ ! -z "$API_ID" ]; then
    aws apigateway delete-rest-api --rest-api-id "$API_ID" --region $REGION
    print_success "✅ API Gateway silindi: $API_LAMBDA_FUNCTION ($API_ID)"
else
    print_warning "⚠️ API Gateway bulunamadı: $API_LAMBDA_FUNCTION"
fi

# 2. Lambda Fonksiyonları Sil
print_info "⚡ Lambda fonksiyonları siliniyor..."

# S3 processor Lambda fonksiyonunu sil
print_info "   Siliniyor: $LAMBDA_FUNCTION"
if aws lambda get-function --function-name "$LAMBDA_FUNCTION" --region $REGION >/dev/null 2>&1; then
    aws lambda delete-function --function-name "$LAMBDA_FUNCTION" --region $REGION
    print_success "   ✅ Silindi: $LAMBDA_FUNCTION"
else
    print_warning "   ⚠️ Bulunamadı: $LAMBDA_FUNCTION"
fi

# API Lambda fonksiyonunu sil
print_info "   Siliniyor: $API_LAMBDA_FUNCTION"
if aws lambda get-function --function-name "$API_LAMBDA_FUNCTION" --region $REGION >/dev/null 2>&1; then
    aws lambda delete-function --function-name "$API_LAMBDA_FUNCTION" --region $REGION
    print_success "   ✅ Silindi: $API_LAMBDA_FUNCTION"
else
    print_warning "   ⚠️ Bulunamadı: $API_LAMBDA_FUNCTION"
fi

# 3. IAM Role Sil
print_info "🔐 IAM Role siliniyor: $ROLE_NAME"
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    # Role'dan policy'leri kaldır
    aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text | while read policy; do
        if [ ! -z "$policy" ]; then
            aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy"
            print_info "   Policy detached: $policy"
        fi
    done
    
    # Inline policy'leri kaldır
    aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames[]' --output text | while read policy; do
        if [ ! -z "$policy" ]; then
            aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$policy"
            print_info "   Inline policy deleted: $policy"
        fi
    done
    
    aws iam delete-role --role-name "$ROLE_NAME"
    print_success "✅ IAM Role silindi: $ROLE_NAME"
else
    print_warning "⚠️ IAM Role bulunamadı: $ROLE_NAME"
fi

# 4. S3 Bucket Sil
print_info "📦 S3 bucket siliniyor: $BUCKET_NAME"
if aws s3 ls "s3://$BUCKET_NAME" --region $REGION >/dev/null 2>&1; then
    # Bucket'ı boşalt
    print_info "   Bucket içeriği siliniyor..."
    aws s3 rm "s3://$BUCKET_NAME" --recursive --region $REGION
    
    # Bucket'ı sil
    aws s3 rb "s3://$BUCKET_NAME" --region $REGION
    print_success "✅ S3 bucket silindi: $BUCKET_NAME"
else
    print_warning "⚠️ S3 bucket bulunamadı: $BUCKET_NAME"
fi

# 5. CloudWatch Log Groups Sil
print_info "📊 CloudWatch log groups siliniyor..."
for func in "$LAMBDA_FUNCTION" "$API_LAMBDA_FUNCTION"; do
    LOG_GROUP="/aws/lambda/$func"
    if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region $REGION --query 'logGroups[].logGroupName' --output text | grep -q "$LOG_GROUP"; then
        aws logs delete-log-group --log-group-name "$LOG_GROUP" --region $REGION
        print_success "✅ Log group silindi: $LOG_GROUP"
    fi
done

echo ""
print_success "🎉 S3 Lambda API başarıyla temizlendi!"
print_success "✅ Tüm kaynaklar silindi"

print_info "💰 Maliyet kontrolü için AWS Billing Dashboard'ı kontrol edin"
