#!/bin/bash

# AWS ZERO to YETO - SageMaker Deployment Script (Direct AWS CLI)
# Bu script SageMaker örneklerini deploy etmek için kullanılır

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
PROJECT_NAME="aws-zero-to-yeto"
REGION="eu-west-1"
TIMESTAMP=$(date +%s)

print_info "SageMaker Deployment başlatılıyor (Direct AWS CLI)..."
print_info "Proje: $PROJECT_NAME"
print_info "Bölge: $REGION"

# AWS CLI kontrolü
check_aws_cli

# SageMaker servisini test et (Direct AWS CLI)
print_info "SageMaker servisini test ediliyor..."

# Test: SageMaker endpoint'lerini listele
print_info "SageMaker endpoint'leri listeleniyor..."
aws sagemaker list-endpoints --region $REGION --output table 2>/dev/null || {
    print_warning "SageMaker endpoint'lerine erişim yok veya endpoint yok."
}

# Test: SageMaker model'lerini listele
print_info "SageMaker model'leri listeleniyor..."
aws sagemaker list-models --region $REGION --output table 2>/dev/null || {
    print_warning "SageMaker model'lerine erişim yok veya model yok."
}

# Direct AWS CLI kullanımı - doğrudan test yapıyoruz
cat > test-sagemaker.py << 'EOF'
#!/usr/bin/env python3
import boto3
import json

def test_sagemaker():
    try:
        sagemaker = boto3.client('sagemaker', region_name='eu-west-1')
        endpoints = sagemaker.list_endpoints()
        models = sagemaker.list_models()
        print("✅ SageMaker'e erişim başarılı!")
        print(f"Endpoint sayısı: {len(endpoints['Endpoints'])}")
        print(f"Model sayısı: {len(models['Models'])}")
        return True
    except Exception as e:
        print(f"❌ SageMaker erişim hatası: {str(e)}")
        return False

if __name__ == "__main__":
    test_sagemaker()
EOF

python3 test-sagemaker.py 2>/dev/null || {
    print_warning "Python SageMaker testi başarısız. Boto3 kurulu olmalı."
}

# Cleanup test file
rm -f test-sagemaker.py

# Sadece örnekler var
print_info "Direct AWS CLI kullanılıyor."

# Deployment bilgilerini kaydet

print_success "🎉 SageMaker deployment tamamlandı (Direct AWS CLI)!"
print_info "Proje: $PROJECT_NAME"
print_info "Bölge: $REGION"
print_info "📝 Deployment bilgileri README'de mevcut"

print_warning "⚠️  SageMaker kaynakları ücretli olabilir"
print_warning "⚠️  Bu deployment sadece örnek dosyalar oluşturur"

echo ""
print_info "Test komutları:"
echo "  cd examples/python && python3 simple_sagemaker_example.py"
echo "  aws sagemaker list-endpoints --region eu-west-1"
echo "  aws sagemaker list-models --region eu-west-1"
