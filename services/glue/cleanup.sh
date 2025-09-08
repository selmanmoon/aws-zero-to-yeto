#!/bin/bash

# AWS ZERO to YETO - Glue Cleanup Script (Direct AWS CLI)
# Bu script Glue kaynaklarını temizler

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

print_info "🧹 Glue Cleanup başlatılıyor (Direct AWS CLI)..."

# AWS CLI kontrolü
check_aws_cli

# Glue kaynaklarını otomatik bul
print_info "🔍 Glue kaynakları aranıyor..."

# S3 bucket'ları bul
BUCKET_NAME=$(aws s3 ls | grep aws-zero-to-yeto-glue | awk '{print $3}' | head -1)

# Glue job'ları bul
CSV_JOB=$(aws glue get-jobs --region $REGION --query 'Jobs[?contains(Name, `csv-to-parquet-job`)].Name' --output text | head -1)
JSON_JOB=$(aws glue get-jobs --region $REGION --query 'Jobs[?contains(Name, `json-to-parquet-job`)].Name' --output text | head -1)

# Glue database'i bul
DATABASE_NAME=$(aws glue get-databases --region $REGION --query 'DatabaseList[?contains(Name, `aws_zero_to_yeto_db`)].Name' --output text | head -1)

# IAM role'ü bul
ROLE_NAME=$(aws iam list-roles --query 'Roles[?contains(RoleName, `aws-zero-to-yeto-glue-role`)].RoleName' --output text | head -1)

print_info "🗑️ Temizlenecek kaynaklar:"
print_info "  S3 Bucket: $BUCKET_NAME"
print_info "  IAM Role: $ROLE_NAME"
print_info "  Database: $DATABASE_NAME"
print_info "  CSV Job: $CSV_JOB"
print_info "  JSON Job: $JSON_JOB"

print_info "🚀 Automatic cleanup başlatılıyor..."

# Glue Job'ları sil
if [ ! -z "$CSV_JOB" ]; then
    print_info "⚙️ CSV Glue Job siliniyor: $CSV_JOB"
    aws glue delete-job --job-name $CSV_JOB --region $REGION 2>/dev/null || true
    print_success "CSV Glue Job silindi"
fi

if [ ! -z "$JSON_JOB" ]; then
    print_info "⚙️ JSON Glue Job siliniyor: $JSON_JOB"
    aws glue delete-job --job-name $JSON_JOB --region $REGION 2>/dev/null || true
    print_success "JSON Glue Job silindi"
fi

# Glue Database sil
if [ ! -z "$DATABASE_NAME" ]; then
    print_info "🗄️ Glue Database siliniyor: $DATABASE_NAME"
    aws glue delete-database --name $DATABASE_NAME --region $REGION 2>/dev/null || true
    print_success "Glue Database silindi"
fi

# IAM Role'den policy'leri ayır ve role'ü sil
if [ ! -z "$ROLE_NAME" ]; then
    print_info "🔐 IAM Role temizleniyor: $ROLE_NAME"
    
    # Attached policy'leri ayır
    aws iam detach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole \
        --region $REGION 2>/dev/null || true
    
    # Inline policy'leri sil
    aws iam delete-role-policy \
        --role-name $ROLE_NAME \
        --policy-name S3AccessPolicy \
        --region $REGION 2>/dev/null || true
    
    # Role'ü sil
    aws iam delete-role --role-name $ROLE_NAME --region $REGION 2>/dev/null || true
    print_success "IAM Role silindi"
fi

# S3 bucket'ı temizle ve sil
if [ ! -z "$BUCKET_NAME" ]; then
    print_info "🪣 S3 bucket temizleniyor: $BUCKET_NAME"
    aws s3 rm s3://$BUCKET_NAME --recursive --region $REGION 2>/dev/null || true
    print_success "S3 bucket içeriği temizlendi"
    
    print_info "🗑️ S3 bucket siliniyor: $BUCKET_NAME"
    aws s3 rb s3://$BUCKET_NAME --region $REGION 2>/dev/null || true
    print_success "S3 bucket silindi"
fi

# Geçici dosyaları temizle
print_info "🧹 Geçici dosyalar temizleniyor..."
rm -f trust-policy.json s3-policy.json 2>/dev/null || true

print_success "🎉 Glue cleanup tamamlandı!"
print_info "✅ Tüm Glue kaynakları temizlendi:"
print_info "  - Glue Job'ları silindi"
print_info "  - Glue Database silindi"
print_info "  - IAM Role ve policy'ler silindi"
print_info "  - S3 bucket ve içeriği silindi"
print_warning "⚠️ Eğer başka kaynaklar varsa, manuel olarak kontrol edin."