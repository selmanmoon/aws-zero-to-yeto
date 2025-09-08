#!/bin/bash

# AWS S3 Cleanup Script
# Bu script S3 bucket'larını ve içeriklerini siler

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="aws-zero-to-yeto"
REGION="eu-west-1"

echo -e "${BLUE}🧹 AWS S3 Cleanup Başlatılıyor...${NC}"
echo -e "${BLUE}📍 Region: $REGION${NC}"
echo -e "${BLUE}🏷️  Project: $PROJECT_NAME${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI bulunamadı. Lütfen AWS CLI'yi yükleyin.${NC}"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials yapılandırılmamış. Lütfen 'aws configure' komutunu çalıştırın.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI ve credentials kontrol edildi${NC}"

# Function to delete S3 bucket and all contents
delete_s3_bucket() {
    local bucket_name="$1"
    
    echo -e "${BLUE}🗑️  S3 bucket siliniyor: $bucket_name${NC}"
    
    # Check if bucket exists
    if ! aws s3 ls "s3://$bucket_name" &> /dev/null; then
        echo -e "${YELLOW}⚠️  $bucket_name bulunamadı (muhtemelen zaten silinmiş)${NC}"
        return 0
    fi
    
    # Delete all objects and versions
    echo -e "${YELLOW}📍 Bucket içeriği siliniyor...${NC}"
    aws s3 rm "s3://$bucket_name" --recursive 2>/dev/null || true
    
    # Delete all versions
    aws s3api delete-objects --bucket "$bucket_name" \
        --delete "$(aws s3api list-object-versions --bucket "$bucket_name" \
        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
        --output json)" 2>/dev/null || true
    
    # Delete all delete markers
    aws s3api delete-objects --bucket "$bucket_name" \
        --delete "$(aws s3api list-object-versions --bucket "$bucket_name" \
        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
        --output json)" 2>/dev/null || true
    
    # Delete the bucket
    echo -e "${YELLOW}📍 Bucket siliniyor...${NC}"
    aws s3 rb "s3://$bucket_name" --force 2>/dev/null || true
    
    echo -e "${GREEN}✅ S3 bucket silindi: $bucket_name${NC}"
}

# Find S3 buckets by project name
echo -e "${BLUE}📋 S3 bucket'ları aranıyor...${NC}"
BUCKETS=$(aws s3api list-buckets \
    --query 'Buckets[?contains(Name, `'$PROJECT_NAME'`)].Name' \
    --output text)

if [ -z "$BUCKETS" ]; then
    echo -e "${YELLOW}⚠️  $PROJECT_NAME projesi için S3 bucket bulunamadı.${NC}"
else
    echo -e "${GREEN}✅ S3 bucket'ları bulundu${NC}"
    
    # Delete each bucket
    for bucket_name in $BUCKETS; do
        if [ ! -z "$bucket_name" ] && [ "$bucket_name" != "None" ]; then
            delete_s3_bucket "$bucket_name"
        fi
    done
fi

# Clean up configuration files
echo -e "${BLUE}📋 Konfigürasyon Dosyaları Temizleniyor...${NC}"
if [ -f "s3-config.json" ]; then
    rm -f s3-config.json
    echo -e "${GREEN}✅ s3-config.json silindi${NC}"
fi

if [ -f "${PROJECT_NAME}-s3-config.json" ]; then
    rm -f "${PROJECT_NAME}-s3-config.json"
    echo -e "${GREEN}✅ ${PROJECT_NAME}-s3-config.json silindi${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}🎉 S3 Cleanup Tamamlandı!${NC}"
echo ""
echo -e "${BLUE}📊 Silinen Kaynaklar:${NC}"
echo -e "  S3 Buckets: $(echo "$BUCKETS" | wc -w) adet"
echo -e "  Objects: Tüm bucket içerikleri"
echo ""
echo -e "${YELLOW}💡 Not:${NC}"
echo -e "  - Tüm S3 bucket'ları ve içerikleri silindi"
echo -e "  - Version'lar ve delete marker'lar temizlendi"
echo -e "  - Konfigürasyon dosyaları temizlendi"
echo ""
echo -e "${BLUE}📁 Konfigürasyon dosyaları temizlendi${NC}"
