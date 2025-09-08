#!/bin/bash

# AWS ZERO to YETO - DynamoDB Cleanup Script (Direct AWS CLI)
# Bu script DynamoDB tablolarını temizlemek için kullanılır

set -e  # Hata durumunda script'i durdur

# Renkli çıktı için fonksiyonlar
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# AWS CLI kontrolü
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI kurulu değil. Lütfen önce AWS CLI'yi kurun."
        exit 1
    fi
    
    # AWS kimlik bilgilerini kontrol et
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS kimlik bilgileri yapılandırılmamış. 'aws configure' komutunu çalıştırın."
        exit 1
    fi
    
    print_success "AWS CLI ve kimlik bilgileri hazır"
}

# Değişkenler
REGION="eu-west-1"
PROJECT_NAME="aws-zero-to-yeto"

print_info "DynamoDB Cleanup başlatılıyor (Direct AWS CLI)..."

# AWS CLI kontrolü
check_aws_cli

# DynamoDB tablolarını bul ve sil
print_info "DynamoDB tabloları aranıyor..."
DYNAMODB_TABLES=$(aws dynamodb list-tables \
    --query 'TableNames[?contains(@, `'$PROJECT_NAME'`)]' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$DYNAMODB_TABLES" ]; then
    print_info "Bulunan DynamoDB tabloları: $DYNAMODB_TABLES"
    
    for table in $DYNAMODB_TABLES; do
        print_info "DynamoDB tablosu siliniyor: $table"
        aws dynamodb delete-table --table-name $table --region $REGION 2>/dev/null || true
        print_success "DynamoDB tablosu silindi: $table"
    done
else
    print_warning "DynamoDB tablosu bulunamadı"
fi

print_success "🎉 DynamoDB cleanup tamamlandı!"
print_info "Tüm DynamoDB tabloları temizlendi"