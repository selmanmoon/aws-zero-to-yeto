#!/bin/bash

# AWS ZERO to YETO - CloudWatch Cleanup Script (Direct AWS CLI)
# Bu script CloudWatch kaynaklarını temizlemek için kullanılır

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

print_info "CloudWatch Cleanup başlatılıyor (Direct AWS CLI)..."

# AWS CLI kontrolü
check_aws_cli

# CloudWatch Log Groups'ları bul ve sil
print_info "CloudWatch Log Groups aranıyor..."
LOG_GROUPS=$(aws logs describe-log-groups \
    --query 'logGroups[?contains(logGroupName, `'$PROJECT_NAME'`)].logGroupName' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$LOG_GROUPS" ]; then
    print_info "Bulunan Log Groups: $LOG_GROUPS"
    
    for log_group in $LOG_GROUPS; do
        print_info "Log group siliniyor: $log_group"
        aws logs delete-log-group --log-group-name $log_group --region $REGION 2>/dev/null || true
        print_success "Log group silindi: $log_group"
    done
else
    print_warning "Log group bulunamadı"
fi

# CloudWatch Alarms'ları bul ve sil
print_info "CloudWatch Alarms aranıyor..."
ALARMS=$(aws cloudwatch describe-alarms \
    --query 'MetricAlarms[?contains(AlarmName, `'$PROJECT_NAME'`)].AlarmName' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$ALARMS" ]; then
    print_info "Bulunan Alarms: $ALARMS"
    
    for alarm in $ALARMS; do
        print_info "Alarm siliniyor: $alarm"
        aws cloudwatch delete-alarms --alarm-names $alarm --region $REGION 2>/dev/null || true
        print_success "Alarm silindi: $alarm"
    done
else
    print_warning "Alarm bulunamadı"
fi

# CloudWatch Dashboards'ları bul ve sil
print_info "CloudWatch Dashboards aranıyor..."
DASHBOARDS=$(aws cloudwatch list-dashboards \
    --query 'DashboardEntries[?contains(DashboardName, `'$PROJECT_NAME'`)].DashboardName' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$DASHBOARDS" ]; then
    print_info "Bulunan Dashboards: $DASHBOARDS"
    
    for dashboard in $DASHBOARDS; do
        print_info "Dashboard siliniyor: $dashboard"
        aws cloudwatch delete-dashboards --dashboard-names $dashboard --region $REGION 2>/dev/null || true
        print_success "Dashboard silindi: $dashboard"
    done
else
    print_warning "Dashboard bulunamadı"
fi

print_success "🎉 CloudWatch cleanup tamamlandı!"
print_info "Tüm CloudWatch log groups, alarms ve dashboards temizlendi"