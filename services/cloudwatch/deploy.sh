#!/bin/bash

# CloudWatch Demo Setup
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

PROJECT_NAME="aws-zero-to-yeto"
TIMESTAMP=$(date +%s)
LOG_GROUP_NAME="/aws/zero-to-yeto/demo-${TIMESTAMP}"

print_info "📊 CloudWatch Demo Setup..."

# 1. Log Group oluştur
aws logs create-log-group --log-group-name "$LOG_GROUP_NAME" 2>/dev/null || true
print_success "Log group oluşturuldu"

# 2. Custom metric gönder
aws cloudwatch put-metric-data \
    --namespace "ZeroToYeto/Demo" \
    --metric-data MetricName=DemoMetric,Value=1,Unit=Count

print_success "Custom metric gönderildi"

# 3. Billing alarm (automatic for testing)
print_info "Billing alarm oluşturuluyor..."
ALARM_NAME="BillingAlert-${TIMESTAMP}"
{
    aws cloudwatch put-metric-alarm \
        --alarm-name "$ALARM_NAME" \
        --alarm-description "Alert when charges exceed $10" \
        --metric-name EstimatedCharges \
        --namespace AWS/Billing \
        --statistic Maximum \
        --period 86400 \
        --threshold 10 \
        --comparison-operator GreaterThanThreshold \
        --evaluation-periods 1
    
    print_success "Billing alarm oluşturuldu"
}

# Bilgi dosyası

print_success "🎉 CloudWatch demo hazır!"
print_info "📝 Deployment bilgileri README'de mevcut"
