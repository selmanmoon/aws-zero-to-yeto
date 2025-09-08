#!/bin/bash

# AWS Service Cleanup Script
# Bu script servis kaynaklarını siler

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
SERVICE_NAME=$(basename $(dirname $(dirname $0)))

echo -e "${BLUE}🧹 AWS $SERVICE_NAME Cleanup Başlatılıyor...${NC}"
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

# Clean up configuration files
echo -e "${BLUE}📋 Konfigürasyon Dosyaları Temizleniyor...${NC}"
if [ -f "${SERVICE_NAME}-config.json" ]; then
    rm -f "${SERVICE_NAME}-config.json"
    echo -e "${GREEN}✅ ${SERVICE_NAME}-config.json silindi${NC}"
fi

if [ -f "${PROJECT_NAME}-${SERVICE_NAME}-config.json" ]; then
    rm -f "${PROJECT_NAME}-${SERVICE_NAME}-config.json"
    echo -e "${GREEN}✅ ${PROJECT_NAME}-${SERVICE_NAME}-config.json silindi${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}🎉 $SERVICE_NAME Cleanup Tamamlandı!${NC}"
echo ""
echo -e "${YELLOW}💡 Not:${NC}"
echo -e "  - $SERVICE_NAME kaynakları temizlendi"
echo -e "  - Konfigürasyon dosyaları temizlendi"
echo ""
echo -e "${BLUE}📁 Konfigürasyon dosyaları temizlendi${NC}"
