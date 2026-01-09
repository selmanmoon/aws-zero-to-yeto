#!/bin/bash

# AWS ZERO to YETO - SQS + SNS Notification Service Temizlik Scripti
# Bu script oluşturulan tüm kaynakları siler

set -e

# Renkli output için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Konfigürasyon
PROJECT_NAME="aws-zero-to-yeto"
REGION="eu-west-1"

echo ""
log_info "🧹 AWS ZERO to YETO - SQS + SNS Notification Service Temizleniyor"
log_info "📍 Region: $REGION"
echo ""

# Config dosyasını kontrol et
if [ ! -f "notification-config.json" ]; then
    log_warning "⚠️ notification-config.json bulunamadı"
    log_info "🔍 Kaynaklar otomatik olarak aranacak..."
    
    # En son oluşturulan kaynakları bul
    QUEUE_NAME=$(aws sqs list-queues --region $REGION --queue-name-prefix "${PROJECT_NAME}-notification-queue" --query 'QueueUrls[-1]' --output text 2>/dev/null | xargs -I {} basename {})
    TOPIC_ARN=$(aws sns list-topics --region $REGION --query "Topics[?contains(TopicArn, '${PROJECT_NAME}-notification-topic')].TopicArn | [-1]" --output text 2>/dev/null)
    TABLE_NAME=$(aws dynamodb list-tables --region $REGION --query "TableNames[?starts_with(@, '${PROJECT_NAME}-notification-logs')] | [-1]" --output text 2>/dev/null)
    PRODUCER_FUNCTION=$(aws lambda list-functions --region $REGION --query "Functions[?starts_with(FunctionName, '${PROJECT_NAME}-notification-producer')].FunctionName | [-1]" --output text 2>/dev/null)
    CONSUMER_FUNCTION=$(aws lambda list-functions --region $REGION --query "Functions[?starts_with(FunctionName, '${PROJECT_NAME}-notification-consumer')].FunctionName | [-1]" --output text 2>/dev/null)
    ROLE_NAME=$(aws iam list-roles --query "Roles[?starts_with(RoleName, '${PROJECT_NAME}-notification-role')].RoleName | [-1]" --output text 2>/dev/null)
    API_ID=$(aws apigateway get-rest-apis --region $REGION --query "items[?starts_with(name, '${PROJECT_NAME}-notification-api')].id | [-1]" --output text 2>/dev/null)
else
    log_info "📄 Config dosyası bulundu, kaynaklar okunuyor..."
    QUEUE_URL=$(cat notification-config.json | grep -o '"url": "[^"]*' | head -1 | cut -d'"' -f4)
    QUEUE_NAME=$(basename "$QUEUE_URL")
    TOPIC_ARN=$(cat notification-config.json | grep -o '"arn": "arn:aws:sns[^"]*' | cut -d'"' -f4)
    TABLE_NAME=$(cat notification-config.json | grep -o '"dynamodb_table": "[^"]*' | cut -d'"' -f4)
    PRODUCER_FUNCTION=$(cat notification-config.json | grep -o '"lambda_producer": "[^"]*' | cut -d'"' -f4)
    CONSUMER_FUNCTION=$(cat notification-config.json | grep -o '"lambda_consumer": "[^"]*' | cut -d'"' -f4)
    ROLE_NAME=$(cat notification-config.json | grep -o '"iam_role": "[^"]*' | cut -d'"' -f4)
    API_ID=$(cat notification-config.json | grep -o '"id": "[^"]*' | tail -1 | cut -d'"' -f4)
fi

log_info "🎯 Hedef kaynaklar:"
log_info "   - SQS Queue: ${QUEUE_NAME:-Bulunamadı}"
log_info "   - SNS Topic: ${TOPIC_ARN:-Bulunamadı}"
log_info "   - DynamoDB Table: ${TABLE_NAME:-Bulunamadı}"
log_info "   - Producer Lambda: ${PRODUCER_FUNCTION:-Bulunamadı}"
log_info "   - Consumer Lambda: ${CONSUMER_FUNCTION:-Bulunamadı}"
log_info "   - IAM Role: ${ROLE_NAME:-Bulunamadı}"
log_info "   - API Gateway: ${API_ID:-Bulunamadı}"
echo ""

# Onay iste
log_warning "⚠️  Bu kaynaklar silinecek!"
read -p "Devam etmek istiyor musunuz? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "❌ İşlem iptal edildi"
    exit 0
fi

echo ""
log_info "🗑️  Kaynaklar siliniyor..."

# 1. API Gateway Sil
if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
    log_info "🌐 API Gateway siliniyor: $API_ID"
    aws apigateway delete-rest-api --rest-api-id $API_ID --region $REGION 2>/dev/null && \
        log_success "✅ API Gateway silindi: $API_ID" || \
        log_warning "⚠️ API Gateway silinemedi: $API_ID"
fi

# 2. Lambda Event Source Mapping Sil
if [ -n "$CONSUMER_FUNCTION" ] && [ "$CONSUMER_FUNCTION" != "None" ]; then
    log_info "🔗 Event source mapping siliniyor..."
    EVENT_SOURCE_UUIDS=$(aws lambda list-event-source-mappings \
        --function-name "$CONSUMER_FUNCTION" \
        --region $REGION \
        --query 'EventSourceMappings[].UUID' \
        --output text 2>/dev/null)
    
    for uuid in $EVENT_SOURCE_UUIDS; do
        aws lambda delete-event-source-mapping --uuid "$uuid" --region $REGION 2>/dev/null && \
            log_success "✅ Event source mapping silindi: $uuid" || \
            log_warning "⚠️ Event source mapping silinemedi: $uuid"
    done
fi

# 3. Consumer Lambda Sil
if [ -n "$CONSUMER_FUNCTION" ] && [ "$CONSUMER_FUNCTION" != "None" ]; then
    log_info "⚡ Consumer Lambda siliniyor: $CONSUMER_FUNCTION"
    aws lambda delete-function --function-name "$CONSUMER_FUNCTION" --region $REGION 2>/dev/null && \
        log_success "✅ Consumer Lambda silindi: $CONSUMER_FUNCTION" || \
        log_warning "⚠️ Consumer Lambda silinemedi: $CONSUMER_FUNCTION"
fi

# 4. Producer Lambda Sil
if [ -n "$PRODUCER_FUNCTION" ] && [ "$PRODUCER_FUNCTION" != "None" ]; then
    log_info "⚡ Producer Lambda siliniyor: $PRODUCER_FUNCTION"
    aws lambda delete-function --function-name "$PRODUCER_FUNCTION" --region $REGION 2>/dev/null && \
        log_success "✅ Producer Lambda silindi: $PRODUCER_FUNCTION" || \
        log_warning "⚠️ Producer Lambda silinemedi: $PRODUCER_FUNCTION"
fi

# 5. SNS Subscriptions ve Topic Sil
if [ -n "$TOPIC_ARN" ] && [ "$TOPIC_ARN" != "None" ]; then
    log_info "📢 SNS subscriptions siliniyor..."
    SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic \
        --topic-arn "$TOPIC_ARN" \
        --region $REGION \
        --query 'Subscriptions[].SubscriptionArn' \
        --output text 2>/dev/null)
    
    for sub in $SUBSCRIPTIONS; do
        if [ "$sub" != "PendingConfirmation" ]; then
            aws sns unsubscribe --subscription-arn "$sub" --region $REGION 2>/dev/null
        fi
    done
    
    log_info "📢 SNS topic siliniyor: $TOPIC_ARN"
    aws sns delete-topic --topic-arn "$TOPIC_ARN" --region $REGION 2>/dev/null && \
        log_success "✅ SNS topic silindi" || \
        log_warning "⚠️ SNS topic silinemedi"
fi

# 6. SQS Queue Sil
if [ -n "$QUEUE_NAME" ] && [ "$QUEUE_NAME" != "None" ]; then
    log_info "📬 SQS queue siliniyor: $QUEUE_NAME"
    QUEUE_URL=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --region $REGION --query 'QueueUrl' --output text 2>/dev/null)
    if [ -n "$QUEUE_URL" ]; then
        aws sqs delete-queue --queue-url "$QUEUE_URL" --region $REGION 2>/dev/null && \
            log_success "✅ SQS queue silindi: $QUEUE_NAME" || \
            log_warning "⚠️ SQS queue silinemedi: $QUEUE_NAME"
    fi
fi

# 7. IAM Role Sil
if [ -n "$ROLE_NAME" ] && [ "$ROLE_NAME" != "None" ]; then
    log_info "🔐 IAM Role siliniyor: $ROLE_NAME"
    
    # Inline policies sil
    INLINE_POLICIES=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames' --output text 2>/dev/null)
    for policy in $INLINE_POLICIES; do
        aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$policy" 2>/dev/null
        log_info "   Inline policy silindi: $policy"
    done
    
    # Role'u sil
    aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null && \
        log_success "✅ IAM Role silindi: $ROLE_NAME" || \
        log_warning "⚠️ IAM Role silinemedi: $ROLE_NAME"
fi

# 8. DynamoDB Table Sil
if [ -n "$TABLE_NAME" ] && [ "$TABLE_NAME" != "None" ]; then
    log_info "📊 DynamoDB tablosu siliniyor: $TABLE_NAME"
    aws dynamodb delete-table --table-name "$TABLE_NAME" --region $REGION 2>/dev/null && \
        log_success "✅ DynamoDB tablosu silindi: $TABLE_NAME" || \
        log_warning "⚠️ DynamoDB tablosu silinemedi: $TABLE_NAME"
fi

# 9. CloudWatch Alarms Sil
log_info "📊 CloudWatch alarmları siliniyor..."
ALARMS=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix "${PROJECT_NAME}-sqs-messages-alarm" \
    --region $REGION \
    --query 'MetricAlarms[].AlarmName' \
    --output text 2>/dev/null)

for alarm in $ALARMS; do
    aws cloudwatch delete-alarms --alarm-names "$alarm" --region $REGION 2>/dev/null && \
        log_success "✅ CloudWatch alarm silindi: $alarm"
done

# 10. CloudWatch Log Groups Sil
log_info "📊 CloudWatch log grupları siliniyor..."
if [ -n "$PRODUCER_FUNCTION" ] && [ "$PRODUCER_FUNCTION" != "None" ]; then
    aws logs delete-log-group --log-group-name "/aws/lambda/$PRODUCER_FUNCTION" --region $REGION 2>/dev/null && \
        log_success "✅ Log group silindi: /aws/lambda/$PRODUCER_FUNCTION" || \
        log_warning "⚠️ Log group bulunamadı: /aws/lambda/$PRODUCER_FUNCTION"
fi

if [ -n "$CONSUMER_FUNCTION" ] && [ "$CONSUMER_FUNCTION" != "None" ]; then
    aws logs delete-log-group --log-group-name "/aws/lambda/$CONSUMER_FUNCTION" --region $REGION 2>/dev/null && \
        log_success "✅ Log group silindi: /aws/lambda/$CONSUMER_FUNCTION" || \
        log_warning "⚠️ Log group bulunamadı: /aws/lambda/$CONSUMER_FUNCTION"
fi

# Config dosyasını sil
if [ -f "notification-config.json" ]; then
    rm -f notification-config.json
    log_info "📄 Config dosyası silindi"
fi

echo ""
log_success "🎉 SQS + SNS Notification Service başarıyla temizlendi!"
log_success "✅ Tüm kaynaklar silindi"
log_info "💰 Maliyet kontrolü için AWS Billing Dashboard'ı kontrol edin"
echo ""
