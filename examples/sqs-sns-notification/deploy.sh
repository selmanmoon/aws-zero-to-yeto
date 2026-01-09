#!/bin/bash

# AWS ZERO to YETO - SQS + SNS Notification Service
# Bu script SQS, SNS, Lambda, API Gateway ve DynamoDB kaynaklarını oluşturur

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
TAGS="Key=Project,Value=$PROJECT_NAME"
TIMESTAMP=$(date +%s)
QUEUE_NAME="${PROJECT_NAME}-notification-queue-${TIMESTAMP}"
TOPIC_NAME="${PROJECT_NAME}-notification-topic-${TIMESTAMP}"
TABLE_NAME="${PROJECT_NAME}-notification-logs-${TIMESTAMP}"
PRODUCER_FUNCTION_NAME="${PROJECT_NAME}-notification-producer-${TIMESTAMP}"
CONSUMER_FUNCTION_NAME="${PROJECT_NAME}-notification-consumer-${TIMESTAMP}"
ROLE_NAME="${PROJECT_NAME}-notification-role-${TIMESTAMP}"
API_NAME="${PROJECT_NAME}-notification-api-${TIMESTAMP}"

echo ""
log_info "🚀 AWS ZERO to YETO - SQS + SNS Notification Service Başlatılıyor"
log_info "📍 Region: $REGION"
log_info "🏷️ Project: $PROJECT_NAME"
echo ""

# 1. DynamoDB Tablosu Oluştur
log_info "📊 DynamoDB tablosu oluşturuluyor..."

aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions \
        AttributeName=message_id,AttributeType=S \
        AttributeName=timestamp,AttributeType=S \
    --key-schema \
        AttributeName=message_id,KeyType=HASH \
        AttributeName=timestamp,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION \
    --tags $TAGS > /dev/null

log_info "⏳ DynamoDB tablosu oluşturuluyor, bekleniyor..."
aws dynamodb wait table-exists \
    --table-name "$TABLE_NAME" \
    --region $REGION
log_success "✅ DynamoDB tablosu oluşturuldu: $TABLE_NAME"

# 2. SNS Topic Oluştur
log_info "📢 SNS topic oluşturuluyor..."

TOPIC_ARN=$(aws sns create-topic \
    --name "$TOPIC_NAME" \
    --region $REGION \
    --tags $TAGS \
    --query 'TopicArn' \
    --output text)

log_success "✅ SNS topic oluşturuldu: $TOPIC_ARN"

# 3. SQS Queue Oluştur
log_info "📬 SQS queue oluşturuluyor..."

QUEUE_URL=$(aws sqs create-queue \
    --queue-name "$QUEUE_NAME" \
    --attributes '{
        "VisibilityTimeout": "60",
        "MessageRetentionPeriod": "86400",
        "ReceiveMessageWaitTimeSeconds": "10"
    }' \
    --region $REGION \
    --tags $TAGS \
    --query 'QueueUrl' \
    --output text)

QUEUE_ARN=$(aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names QueueArn \
    --region $REGION \
    --query 'Attributes.QueueArn' \
    --output text)

log_success "✅ SQS queue oluşturuldu: $QUEUE_URL"

# 4. IAM Role Oluştur
log_info "🔐 IAM role oluşturuluyor..."

# Trust policy
cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --tags $TAGS > /dev/null

# Lambda permissions policy
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

cat > lambda-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sqs:SendMessage",
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes"
            ],
            "Resource": "$QUEUE_ARN"
        },
        {
            "Effect": "Allow",
            "Action": [
                "sns:Publish"
            ],
            "Resource": "$TOPIC_ARN"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:GetItem",
                "dynamodb:Query",
                "dynamodb:Scan"
            ],
            "Resource": "arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/$TABLE_NAME"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:$REGION:$ACCOUNT_ID:*"
        }
    ]
}
EOF

aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name LambdaNotificationPolicy \
    --policy-document file://lambda-policy.json

log_info "⏳ IAM role oluşturuluyor, bekleniyor..."
sleep 10
log_success "✅ IAM role oluşturuldu: $ROLE_NAME"

# 5. Producer Lambda Fonksiyonu Oluştur
log_info "⚡ Producer Lambda fonksiyonu oluşturuluyor..."

cat > producer_function.py << 'PRODUCER_EOF'
import json
import boto3
import os
import uuid
from datetime import datetime

sqs = boto3.client('sqs')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """API Gateway'den gelen mesajı SQS'e gönderir"""
    
    queue_url = os.environ['QUEUE_URL']
    table_name = os.environ['TABLE_NAME']
    table = dynamodb.Table(table_name)
    
    try:
        # Request body'yi parse et
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        message_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        # Mesaj içeriği
        message = {
            'message_id': message_id,
            'timestamp': timestamp,
            'recipient': body.get('recipient', 'default@example.com'),
            'subject': body.get('subject', 'Bildirim'),
            'message': body.get('message', 'Merhaba!'),
            'notification_type': body.get('type', 'email'),
            'status': 'queued'
        }
        
        # SQS'e gönder
        sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(message),
            MessageAttributes={
                'notification_type': {
                    'DataType': 'String',
                    'StringValue': message['notification_type']
                }
            }
        )
        
        # DynamoDB'ye logla
        table.put_item(Item=message)
        
        print(f"✅ Mesaj kuyruğa eklendi: {message_id}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': True,
                'message_id': message_id,
                'status': 'queued',
                'info': 'Mesaj başarıyla kuyruğa eklendi'
            }, ensure_ascii=False)
        }
        
    except Exception as e:
        print(f"❌ Hata: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': False,
                'error': str(e)
            })
        }
PRODUCER_EOF

zip -r producer_function.zip producer_function.py > /dev/null

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/$ROLE_NAME"

aws lambda create-function \
    --function-name "$PRODUCER_FUNCTION_NAME" \
    --runtime python3.9 \
    --role "$ROLE_ARN" \
    --handler producer_function.lambda_handler \
    --zip-file fileb://producer_function.zip \
    --timeout 30 \
    --memory-size 128 \
    --environment "Variables={QUEUE_URL=$QUEUE_URL,TABLE_NAME=$TABLE_NAME}" \
    --region $REGION \
    --tags $TAGS > /dev/null

log_success "✅ Producer Lambda oluşturuldu: $PRODUCER_FUNCTION_NAME"

# 6. Consumer Lambda Fonksiyonu Oluştur
log_info "⚡ Consumer Lambda fonksiyonu oluşturuluyor..."

cat > consumer_function.py << 'CONSUMER_EOF'
import json
import boto3
import os
from datetime import datetime

sns = boto3.client('sns')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """SQS'ten mesaj alıp SNS'e gönderir ve DynamoDB'yi günceller"""
    
    topic_arn = os.environ['TOPIC_ARN']
    table_name = os.environ['TABLE_NAME']
    table = dynamodb.Table(table_name)
    
    processed_count = 0
    
    for record in event.get('Records', []):
        try:
            # SQS mesajını parse et
            message = json.loads(record['body'])
            message_id = message['message_id']
            timestamp = message['timestamp']
            
            print(f"📥 Mesaj işleniyor: {message_id}")
            
            # SNS'e bildirim gönder
            sns_message = f"""
🔔 Yeni Bildirim

📧 Alıcı: {message['recipient']}
📌 Konu: {message['subject']}
💬 Mesaj: {message['message']}
📅 Tarih: {timestamp}
🆔 ID: {message_id}
            """
            
            sns.publish(
                TopicArn=topic_arn,
                Message=sns_message,
                Subject=f"AWS Bildirim: {message['subject']}"
            )
            
            # DynamoDB'yi güncelle
            table.update_item(
                Key={
                    'message_id': message_id,
                    'timestamp': timestamp
                },
                UpdateExpression='SET #status = :status, processed_at = :processed_at',
                ExpressionAttributeNames={
                    '#status': 'status'
                },
                ExpressionAttributeValues={
                    ':status': 'sent',
                    ':processed_at': datetime.utcnow().isoformat()
                }
            )
            
            processed_count += 1
            print(f"✅ Mesaj işlendi ve gönderildi: {message_id}")
            
        except Exception as e:
            print(f"❌ Mesaj işlenirken hata: {str(e)}")
            continue
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'processed': processed_count
        })
    }
CONSUMER_EOF

zip -r consumer_function.zip consumer_function.py > /dev/null

aws lambda create-function \
    --function-name "$CONSUMER_FUNCTION_NAME" \
    --runtime python3.9 \
    --role "$ROLE_ARN" \
    --handler consumer_function.lambda_handler \
    --zip-file fileb://consumer_function.zip \
    --timeout 60 \
    --memory-size 128 \
    --environment "Variables={TOPIC_ARN=$TOPIC_ARN,TABLE_NAME=$TABLE_NAME}" \
    --region $REGION \
    --tags $TAGS > /dev/null

log_success "✅ Consumer Lambda oluşturuldu: $CONSUMER_FUNCTION_NAME"

# 7. SQS Trigger Ekle (Lambda Event Source Mapping)
log_info "🔗 SQS trigger ekleniyor..."

aws lambda create-event-source-mapping \
    --function-name "$CONSUMER_FUNCTION_NAME" \
    --batch-size 5 \
    --event-source-arn "$QUEUE_ARN" \
    --region $REGION > /dev/null

log_success "✅ SQS trigger eklendi"

# 8. API Gateway Oluştur
log_info "🌐 API Gateway oluşturuluyor..."

API_ID=$(aws apigateway create-rest-api \
    --name "$API_NAME" \
    --region $REGION \
    --tags $TAGS \
    --query 'id' \
    --output text)

ROOT_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region $REGION \
    --query 'items[0].id' \
    --output text)

# /notify endpoint oluştur
RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part "notify" \
    --region $REGION \
    --query 'id' \
    --output text)

# POST method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE \
    --region $REGION > /dev/null

# Lambda Integration
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$PRODUCER_FUNCTION_NAME/invocations" \
    --region $REGION > /dev/null

# Lambda permission
aws lambda add-permission \
    --function-name "$PRODUCER_FUNCTION_NAME" \
    --statement-id "apigateway-invoke" \
    --action "lambda:InvokeFunction" \
    --principal "apigateway.amazonaws.com" \
    --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/POST/notify" \
    --region $REGION > /dev/null

# Deploy API
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region $REGION > /dev/null

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/notify"

log_success "✅ API Gateway oluşturuldu: $API_URL"

# 9. CloudWatch Alarm Oluştur
log_info "📊 CloudWatch alarm oluşturuluyor..."

aws cloudwatch put-metric-alarm \
    --alarm-name "${PROJECT_NAME}-sqs-messages-alarm-${TIMESTAMP}" \
    --alarm-description "SQS kuyrukta bekleyen mesaj sayısı yüksekse alarm" \
    --metric-name ApproximateNumberOfMessagesVisible \
    --namespace AWS/SQS \
    --statistic Average \
    --period 300 \
    --threshold 100 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=QueueName,Value=$QUEUE_NAME \
    --evaluation-periods 2 \
    --region $REGION \
    --tags $TAGS > /dev/null

log_success "✅ CloudWatch alarm oluşturuldu"

# 10. Konfigürasyon dosyasını kaydet
log_info "💾 Konfigürasyon kaydediliyor..."

cat > notification-config.json << EOF
{
    "project_name": "$PROJECT_NAME",
    "region": "$REGION",
    "timestamp": "$TIMESTAMP",
    "resources": {
        "sqs_queue": {
            "name": "$QUEUE_NAME",
            "url": "$QUEUE_URL",
            "arn": "$QUEUE_ARN"
        },
        "sns_topic": {
            "name": "$TOPIC_NAME",
            "arn": "$TOPIC_ARN"
        },
        "dynamodb_table": "$TABLE_NAME",
        "lambda_producer": "$PRODUCER_FUNCTION_NAME",
        "lambda_consumer": "$CONSUMER_FUNCTION_NAME",
        "iam_role": "$ROLE_NAME",
        "api_gateway": {
            "id": "$API_ID",
            "url": "$API_URL"
        }
    }
}
EOF

# Geçici dosyaları temizle
rm -f trust-policy.json lambda-policy.json producer_function.py consumer_function.py producer_function.zip consumer_function.zip

echo ""
log_success "🎉 SQS + SNS Notification Service başarıyla oluşturuldu!"
echo ""
echo "📋 Oluşturulan Kaynaklar:"
echo "  - SQS Queue: $QUEUE_NAME"
echo "  - SNS Topic: $TOPIC_NAME"
echo "  - DynamoDB Table: $TABLE_NAME"
echo "  - Producer Lambda: $PRODUCER_FUNCTION_NAME"
echo "  - Consumer Lambda: $CONSUMER_FUNCTION_NAME"
echo "  - API Gateway: $API_URL"
echo ""
echo "🧪 Test Etmek İçin:"
echo ""
echo "1. Email aboneliği ekle (kendi email adresinizi yazın):"
echo "   aws sns subscribe --topic-arn $TOPIC_ARN --protocol email --notification-endpoint YOUR_EMAIL@example.com --region $REGION"
echo ""
echo "2. API'ye mesaj gönder:"
echo "   curl -X POST '$API_URL' \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"recipient\": \"test@example.com\", \"subject\": \"Test Bildirimi\", \"message\": \"Merhaba AWS!\"}'"
echo ""
echo "📊 Mesajları Kontrol Etmek İçin:"
echo "   aws dynamodb scan --table-name $TABLE_NAME --region $REGION"
echo ""
echo "🧹 Temizlik İçin:"
echo "   ./cleanup.sh"
echo ""
