#!/bin/bash

# AWS ZERO to YETO - IoT Veri İşleme Pipeline Temizlik
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
PROJECT_NAME="aws-zero-to-yeto"
REGION="eu-west-1"

print_info "🧹 AWS ZERO to YETO - IoT Veri İşleme Pipeline Temizleniyor"
print_info "📍 Region: $REGION"

# En son deploy edilen kaynakları bul (timestamp'a göre en yüksek)
print_info "🔍 En son deploy edilen kaynakları aranıyor..."

# En yüksek timestamp'li kaynakları bul
LATEST_TIMESTAMP=$(aws dynamodb list-tables --region $REGION --query "TableNames[?contains(@, 'iot-data')]" --output text | sed 's/.*iot-data-\([0-9]*\)/\1/' | sort -n | tail -1)

if [ -z "$LATEST_TIMESTAMP" ]; then
    print_warning "IoT Data Pipeline kaynakları bulunamadı"
    exit 0
fi

TABLE_NAME="${PROJECT_NAME}-iot-data-${LATEST_TIMESTAMP}"
ROLE_NAME="${PROJECT_NAME}-iot-lambda-role-${LATEST_TIMESTAMP}"
FUNCTION_NAME="${PROJECT_NAME}-iot-processor-${LATEST_TIMESTAMP}"
ALARM_NAME="${PROJECT_NAME}-iot-message-alarm"
RULE_NAME="${PROJECT_NAME}-iot-rule"
POLICY_NAME="${PROJECT_NAME}-iot-policy"
THING_NAME="${PROJECT_NAME}-sensor-device"

print_info "🎯 Hedef kaynaklar:"
print_info "   - DynamoDB Table: $TABLE_NAME"
print_info "   - Lambda Function: $FUNCTION_NAME"
print_info "   - IAM Role: $ROLE_NAME"
print_info "   - IoT Thing: $THING_NAME"
print_info "   - IoT Rule: $RULE_NAME"
print_info "   - IoT Policy: $POLICY_NAME"
print_info "   - CloudWatch Alarm: $ALARM_NAME"

echo ""
print_warning "⚠️  Bu kaynaklar silinecek!"
read -p "Devam etmek istiyor musunuz? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_info "İşlem iptal edildi"
    exit 0
fi

echo ""
print_info "🗑️  Kaynaklar siliniyor..."

# 1. CloudWatch Alarm Sil
print_info "📊 CloudWatch alarm siliniyor: $ALARM_NAME"
if aws cloudwatch describe-alarms --alarm-names "$ALARM_NAME" --region $REGION >/dev/null 2>&1; then
    aws cloudwatch delete-alarms --alarm-names "$ALARM_NAME" --region $REGION
    print_success "✅ CloudWatch alarm silindi: $ALARM_NAME"
else
    print_warning "⚠️ CloudWatch alarm bulunamadı: $ALARM_NAME"
fi

# 2. IoT Rule Sil
print_info "📋 IoT Rule siliniyor: $RULE_NAME"
if aws iot get-topic-rule --rule-name "$RULE_NAME" --region $REGION >/dev/null 2>&1; then
    aws iot delete-topic-rule --rule-name "$RULE_NAME" --region $REGION
    print_success "✅ IoT Rule silindi: $RULE_NAME"
else
    print_warning "⚠️ IoT Rule bulunamadı: $RULE_NAME"
fi

# 3. IoT Policy Sil
print_info "🔐 IoT Policy siliniyor: $POLICY_NAME"
if aws iot get-policy --policy-name "$POLICY_NAME" --region $REGION >/dev/null 2>&1; then
    # Policy'yi thing'lerden ayır
    aws iot list-things --region $REGION --query 'things[?contains(tags[?key==`Project`].value, `'$PROJECT_NAME'`)].thingName' --output text | while read thing; do
        if [ ! -z "$thing" ]; then
            aws iot detach-policy --policy-name "$POLICY_NAME" --target "$thing" --region $REGION 2>/dev/null || true
        fi
    done
    
    aws iot delete-policy --policy-name "$POLICY_NAME" --region $REGION
    print_success "✅ IoT Policy silindi: $POLICY_NAME"
else
    print_warning "⚠️ IoT Policy bulunamadı: $POLICY_NAME"
fi

# 4. IoT Thing Sil
print_info "🌐 IoT Thing siliniyor: $THING_NAME"
if aws iot describe-thing --thing-name "$THING_NAME" --region $REGION >/dev/null 2>&1; then
    aws iot delete-thing --thing-name "$THING_NAME" --region $REGION
    print_success "✅ IoT Thing silindi: $THING_NAME"
else
    print_warning "⚠️ IoT Thing bulunamadı: $THING_NAME"
fi

# 5. Lambda Fonksiyonu Sil
print_info "⚡ Lambda fonksiyonu siliniyor: $FUNCTION_NAME"
if aws lambda get-function --function-name "$FUNCTION_NAME" --region $REGION >/dev/null 2>&1; then
    aws lambda delete-function --function-name "$FUNCTION_NAME" --region $REGION
    print_success "✅ Lambda fonksiyonu silindi: $FUNCTION_NAME"
else
    print_warning "⚠️ Lambda fonksiyonu bulunamadı: $FUNCTION_NAME"
fi

# 6. IAM Role Sil
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

# 7. DynamoDB Tablosu Sil
print_info "📊 DynamoDB tablosu siliniyor: $TABLE_NAME"
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region $REGION >/dev/null 2>&1; then
    aws dynamodb delete-table --table-name "$TABLE_NAME" --region $REGION
    print_info "⏳ DynamoDB tablosu siliniyor, bekleniyor..."
    aws dynamodb wait table-not-exists --table-name "$TABLE_NAME" --region $REGION
    print_success "✅ DynamoDB tablosu silindi: $TABLE_NAME"
else
    print_warning "⚠️ DynamoDB tablosu bulunamadı: $TABLE_NAME"
fi

# 8. CloudWatch Log Group Sil
print_info "📊 CloudWatch log group siliniyor..."
LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region $REGION --query 'logGroups[].logGroupName' --output text | grep -q "$LOG_GROUP"; then
    aws logs delete-log-group --log-group-name "$LOG_GROUP" --region $REGION
    print_success "✅ Log group silindi: $LOG_GROUP"
else
    print_warning "⚠️ Log group bulunamadı: $LOG_GROUP"
fi

echo ""
print_success "🎉 IoT Veri İşleme Pipeline başarıyla temizlendi!"
print_success "✅ Tüm kaynaklar silindi"

print_info "💰 Maliyet kontrolü için AWS Billing Dashboard'ı kontrol edin"