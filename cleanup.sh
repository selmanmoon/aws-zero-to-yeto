#!/bin/bash

# AWS ZERO to YETO - Master Cleanup Script (Direct AWS CLI)
# Bu script tüm servisleri ters sırada temizler

set -e  # Hata durumunda script'i durdur

# Renkli çıktı için fonksiyonlar
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🧹 $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

# Cleanup fonksiyonu
cleanup_service() {
    local service_name="$1"
    local service_path="services/${service_name}"
    
    print_header "CLEANING UP $(echo $service_name | tr '[:lower:]' '[:upper:]') SERVICE"
    
    if [ ! -d "$service_path" ]; then
        print_warning "Service directory not found: $service_path (skipping)"
        return 0
    fi
    
    if [ ! -f "$service_path/cleanup.sh" ]; then
        print_warning "Cleanup script not found: $service_path/cleanup.sh (skipping)"
        return 0
    fi
    
    # Servis dizini var mı kontrol et
    if [ ! -d "$service_path" ]; then
        print_warning "Service directory not found for $service_name (probably not deployed)"
        return 0
    fi
    
    print_info "Cleaning up $service_name service..."
    cd "$service_path"
    
    if ! chmod +x cleanup.sh; then
        print_error "Failed to make cleanup.sh executable"
        cd - > /dev/null
        return 1
    fi
    
    if ./cleanup.sh; then
        print_success "$service_name service cleaned up successfully!"
        cd - > /dev/null
        return 0
    else
        print_error "$service_name service cleanup failed!"
        cd - > /dev/null
        return 1
    fi
}

# Ana başlık
print_header "AWS ZERO to YETO - Master Cleanup (Direct AWS CLI)"
print_info "Cleanup başlatılıyor..."
print_info "Direct AWS CLI kullanılıyor"

# AWS CLI kontrolü
check_aws_cli

# Cleanup başlangıç zamanı
START_TIME=$(date +%s)

# Servis cleanup sırası (deploy'un tersi - dependency'ler önce temizlenmeli)
SERVICES=(
    "rds"       # En uzun süren ilk temizlenmeli
    "sagemaker"
    "glue"
    "bedrock"
    "cloudwatch"
    "iam"
    "dynamodb"
    "lambda"
    "s3"        # En son temizlenmeli (diğer servisler S3 kullanabilir)
)

# Cleanup sayaçları
TOTAL_SERVICES=${#SERVICES[@]}
SUCCESSFUL_CLEANUPS=0
FAILED_CLEANUPS=0
SKIPPED_CLEANUPS=0

print_info "Toplam ${TOTAL_SERVICES} servis temizlenecek"
echo ""

# Her servisi temizle
for i in "${!SERVICES[@]}"; do
    service=${SERVICES[$i]}
    current=$((i + 1))
    
    print_info "[$current/$TOTAL_SERVICES] Starting cleanup: $service"
    
    if cleanup_service "$service"; then
        SUCCESSFUL_CLEANUPS=$((SUCCESSFUL_CLEANUPS + 1))
        print_success "✅ $service cleanup completed"
    else
        FAILED_CLEANUPS=$((FAILED_CLEANUPS + 1))
        print_error "❌ $service cleanup failed"
        
        # Hata durumunda devam et
        print_warning "Continuing with next service..."
    fi
    
    echo ""
done

# Cleanup süresi hesapla
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Final rapor
print_header "CLEANUP SUMMARY"
print_info "Toplam süre: ${MINUTES}m ${SECONDS}s"
print_info "Başarılı cleanups: $SUCCESSFUL_CLEANUPS/$TOTAL_SERVICES"
print_info "Başarısız cleanups: $FAILED_CLEANUPS/$TOTAL_SERVICES"

if [ $FAILED_CLEANUPS -eq 0 ]; then
    print_success "🎉 Tüm servisler başarıyla temizlendi!"
    exit 0
else
    print_warning "⚠️  Bazı servisler temizlenemedi. Detaylar için yukarıdaki logları kontrol edin."
    exit 1
fi
