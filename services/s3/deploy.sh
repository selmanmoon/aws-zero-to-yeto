#!/bin/bash

# AWS ZERO to YETO - S3 Deployment Script
# Bu script S3 örneklerini deploy etmek için kullanılır

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
BUCKET_NAME="aws-zero-to-yeto-$(date +%s)"
REGION="eu-west-1"
PROJECT_NAME="aws-zero-to-yeto-s3"

print_info "S3 Deployment başlatılıyor..."
print_info "Bucket adı: $BUCKET_NAME"
print_info "Bölge: $REGION"

# AWS CLI kontrolü
check_aws_cli

# S3 Bucket oluştur
print_info "S3 bucket oluşturuluyor..."
aws s3 mb s3://$BUCKET_NAME --region $REGION

# Bucket güvenlik ayarları (public access tamamen kapalı)
print_info "Bucket güvenlik ayarları yapılıyor..."
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Örnek dosyalar oluştur ve yükle
print_info "Örnek dosyalar oluşturuluyor..."

# Örnek dosyalar oluştur
echo "Bu bir örnek doküman dosyasıdır." > sample-document.txt
echo "Bu bir örnek log dosyasıdır." > sample-log.txt
echo "Bu bir örnek veri dosyasıdır." > sample-data.txt

# Dosyaları S3'e yükle
print_info "Dosyalar S3'e yükleniyor..."
aws s3 cp sample-document.txt s3://$BUCKET_NAME/
aws s3 cp sample-log.txt s3://$BUCKET_NAME/
aws s3 cp sample-data.txt s3://$BUCKET_NAME/

# Örnek klasör yapısı oluştur
print_info "Klasör yapısı oluşturuluyor..."
aws s3api put-object --bucket $BUCKET_NAME --key documents/
aws s3api put-object --bucket $BUCKET_NAME --key backups/
aws s3api put-object --bucket $BUCKET_NAME --key data/

# Dosyaları klasörlere yükle
aws s3 cp sample-document.txt s3://$BUCKET_NAME/documents/
aws s3 cp sample-log.txt s3://$BUCKET_NAME/backups/
aws s3 cp sample-data.txt s3://$BUCKET_NAME/data/

# Bucket policy oluştur (güvenli - sadece owner erişimi)
print_info "Bucket policy oluşturuluyor..."
cat > bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "OwnerAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):root"
            },
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::$BUCKET_NAME",
                "arn:aws:s3:::$BUCKET_NAME/*"
            ]
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://bucket-policy.json || print_warning "Bucket policy ayarlanamadı, devam ediliyor..."

# Deployment bilgilerini README'ye yaz
print_info "📝 Deployment bilgileri README'de mevcut"

# Temizlik
rm -f bucket-policy.json sample-document.txt sample-log.txt sample-data.txt

print_success "🎉 S3 deployment tamamlandı!"
print_info "S3 Console: https://s3.console.aws.amazon.com/s3/buckets/$BUCKET_NAME"
print_info "Deployment bilgileri README'de mevcut"

print_success "✅ Bucket güvenli şekilde oluşturuldu - public erişim kapalı"

echo ""
print_info "Test komutları:"
echo "  aws s3 ls s3://$BUCKET_NAME/"
echo "  aws s3 cp test.txt s3://$BUCKET_NAME/"
echo "  aws s3 rm s3://$BUCKET_NAME/test.txt"

Çalıştırma işlemi için:
Terminalden cd services
 cd s3
 ./deploy.sh  deploy etme
  ./cleanup.sh temizleme 
 ile calistirip