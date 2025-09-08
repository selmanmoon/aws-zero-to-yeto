#!/bin/bash

# AWS ZERO to YETO - IoT Veri İşleme Pipeline
# Bu script IoT Core, Lambda, DynamoDB ve CloudWatch kaynaklarını oluşturur

set -e

# Konfigürasyon
PROJECT_NAME="aws-zero-to-yeto"
REGION="eu-west-1"
TAGS="Key=Project,Value=$PROJECT_NAME"
TIMESTAMP=$(date +%s)
TABLE_NAME="${PROJECT_NAME}-iot-data-${TIMESTAMP}"
ROLE_NAME="${PROJECT_NAME}-iot-lambda-role-${TIMESTAMP}"
FUNCTION_NAME="${PROJECT_NAME}-iot-processor-${TIMESTAMP}"

echo "🚀 AWS ZERO to YETO - IoT Veri İşleme Pipeline Başlatılıyor"
echo "📍 Region: $REGION"
echo "🏷️ Project: $PROJECT_NAME"

# 1. DynamoDB Tablosu Oluştur
echo "📊 DynamoDB tablosu oluşturuluyor..."

aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=device_id,AttributeType=S AttributeName=timestamp,AttributeType=S \
    --key-schema AttributeName=device_id,KeyType=HASH AttributeName=timestamp,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION \
    --tags $TAGS

echo "⏳ DynamoDB tablosu oluşturuluyor, bekleniyor..."
aws dynamodb wait table-exists \
    --table-name "$TABLE_NAME" \
    --region $REGION

# 2. IAM Role Oluştur (Lambda için)
echo "🔐 IAM role oluşturuluyor..."


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
    --tags $TAGS

# DynamoDB policy
cat > dynamodb-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:Query",
                "dynamodb:Scan"
            ],
            "Resource": "arn:aws:dynamodb:$REGION:*:table/$TABLE_NAME"
        }
    ]
}
EOF

aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name DynamoDBPolicy \
    --policy-document file://dynamodb-policy.json

# CloudWatch Logs policy
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Role'un oluşturulmasını bekle
echo "⏳ IAM role oluşturuluyor, bekleniyor..."
sleep 10

# 3. Lambda Fonksiyonu Oluştur
echo "⚡ Lambda fonksiyonu oluşturuluyor..."

# Lambda kodunu oluştur
cat > lambda_function.py << 'EOF'
import json
import boto3
import datetime
import os
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    """IoT verilerini DynamoDB'ye kaydeder"""
    
    print(f"📥 Gelen veri: {json.dumps(event)}")
    
    try:
        # IoT Core'dan gelen mesajı parse et
        if 'device_id' in event:
            # Direkt payload formatı
            payload = event
            topic = 'sensors/temperature'  # Default topic
            
            # Veriyi hazırla
            item = {
                'device_id': payload.get('device_id', 'unknown'),
                'timestamp': payload.get('timestamp', datetime.datetime.utcnow().isoformat()),
                'topic': topic,
                'temperature': Decimal(str(payload.get('temperature', 0))),
                'humidity': Decimal(str(payload.get('humidity', 0))),
                'pressure': Decimal(str(payload.get('pressure', 0))),
                'processed_at': datetime.datetime.utcnow().isoformat()
            }
            
            # DynamoDB'ye kaydet
            table.put_item(Item=item)
            
            print(f"✅ Veri kaydedildi: {item['device_id']} - {item['timestamp']}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Veri başarıyla kaydedildi',
                    'device_id': item['device_id'],
                    'timestamp': item['timestamp']
                })
            }
        else:
            print("❌ Geçersiz mesaj formatı")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Geçersiz mesaj formatı'})
            }
            
    except Exception as e:
        print(f"❌ Hata: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
EOF

# Lambda deployment package oluştur
zip -r lambda_function.zip lambda_function.py

# Lambda fonksiyonunu oluştur
aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.9 \
    --role "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$ROLE_NAME" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda_function.zip \
    --timeout 30 \
    --memory-size 128 \
    --environment Variables="{TABLE_NAME=$TABLE_NAME}" \
    --region $REGION \
    --tags $TAGS

# 4. IoT Core Thing Oluştur
echo "🌐 IoT Core Thing oluşturuluyor..."
THING_NAME="${PROJECT_NAME}-sensor-device"

aws iot create-thing \
    --thing-name $THING_NAME \
    --region $REGION

# 5. IoT Policy Oluştur
echo "🔐 IoT policy oluşturuluyor..."
POLICY_NAME="${PROJECT_NAME}_iot_policy_${TIMESTAMP}"

cat > iot-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iot:Publish",
                "iot:Subscribe",
                "iot:Connect",
                "iot:Receive"
            ],
            "Resource": [
                "arn:aws:iot:$REGION:*:topic/sensors/*",
                "arn:aws:iot:$REGION:*:topicfilter/sensors/*",
                "arn:aws:iot:$REGION:*:client/\${iot:Connection.Thing.ThingName}"
            ]
        }
    ]
}
EOF

aws iot create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://iot-policy.json \
    --region $REGION

# 6. IoT Rule Oluştur (Lambda'ya yönlendirme)
echo "📋 IoT Rule oluşturuluyor..."
RULE_NAME="iot_rule_${TIMESTAMP}"

# Rule action (Lambda'ya yönlendirme)
cat > rule-action.json << EOF
{
    "lambda": {
        "functionArn": "arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$FUNCTION_NAME"
    }
}
EOF

# Rule oluştur
aws iot create-topic-rule \
    --rule-name $RULE_NAME \
    --topic-rule-payload "{\"sql\":\"SELECT * FROM 'sensors/#'\",\"actions\":[$(cat rule-action.json)]}" \
    --region $REGION

# Lambda'ya IoT invoke izni ver
aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id "iot-invoke" \
    --action "lambda:InvokeFunction" \
    --principal "iot.amazonaws.com" \
    --source-arn "arn:aws:iot:$REGION:$(aws sts get-caller-identity --query Account --output text):rule/$RULE_NAME" \
    --region $REGION

# 7. CloudWatch Alarm Oluştur
echo "📊 CloudWatch alarm oluşturuluyor..."
aws cloudwatch put-metric-alarm \
    --alarm-name "${PROJECT_NAME}-iot-message-alarm" \
    --alarm-description "IoT mesaj sayısı düşükse alarm" \
    --metric-name "MessagesPublished" \
    --namespace "AWS/IoT" \
    --statistic Sum \
    --period 300 \
    --threshold 1 \
    --comparison-operator LessThanThreshold \
    --evaluation-periods 2 \
    --region $REGION \
    --tags $TAGS

# 8. Konfigürasyon dosyasını kaydet
echo "💾 Konfigürasyon kaydediliyor..."
cat > iot-config.json << EOF
{
    "project_name": "$PROJECT_NAME",
    "region": "$REGION",
    "dynamodb_table": "$TABLE_NAME",
    "lambda_function": "$FUNCTION_NAME",
    "iot_thing": "$THING_NAME",
    "iot_rule": "$RULE_NAME",
    "cloudwatch_alarm": "${PROJECT_NAME}-iot-message-alarm"
}
EOF

# 9. Test verisi gönder
echo "🧪 Test verisi gönderiliyor..."
aws iot-data publish \
    --topic "sensors/temperature" \
    --payload '{"device_id": "test-sensor-001", "temperature": 25.5, "humidity": 60, "pressure": 1013.25, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
    --region $REGION

echo ""
echo "🎉 IoT Veri İşleme Pipeline başarıyla oluşturuldu!"
echo ""
echo "📋 Oluşturulan Kaynaklar:"
echo "  - DynamoDB Tablosu: $TABLE_NAME"
echo "  - Lambda Fonksiyonu: $FUNCTION_NAME"
echo "  - IoT Thing: $THING_NAME"
echo "  - IoT Rule: $RULE_NAME"
echo "  - CloudWatch Alarm: ${PROJECT_NAME}-iot-message-alarm"
echo ""
echo "🧪 Test Etmek İçin:"
echo "aws iot-data publish --topic 'sensors/temperature' --payload '{\"device_id\": \"test-sensor-001\", \"temperature\": 25.5, \"humidity\": 60, \"timestamp\": \"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'\"}'"
echo ""
echo "📊 Veriyi Kontrol Etmek İçin:"
echo "aws dynamodb scan --table-name ${PROJECT_NAME}-iot-data"
echo ""
echo "🧹 Temizlik İçin:"
echo "./cleanup.sh"

# Geçici dosyaları temizle
rm -f trust-policy.json dynamodb-policy.json iot-policy.json rule-action.json lambda_function.py lambda_function.zip
