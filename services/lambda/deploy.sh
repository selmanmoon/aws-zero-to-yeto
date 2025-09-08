#!/bin/bash

# AWS ZERO to YETO - Lambda Deployment Script
# Bu script Lambda örneklerini deploy etmek için kullanılır

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
PROJECT_NAME="aws-zero-to-yeto-lambda"
REGION="eu-west-1"
STACK_NAME="${PROJECT_NAME}-$(date +%s)"

print_info "Lambda Deployment başlatılıyor..."
print_info "Stack adı: $STACK_NAME"
print_info "Bölge: $REGION"

# AWS CLI kontrolü
check_aws_cli

# Gerekli klasörleri oluştur
print_info "Klasör yapısı oluşturuluyor..."
mkdir -p examples/python examples/nodejs templates

# Python Lambda fonksiyonu oluştur
print_info "Python Lambda fonksiyonu oluşturuluyor..."
cat > examples/python/lambda_function.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AWS ZERO to YETO - Lambda Örnek Fonksiyonu
"""

import json
import logging
import boto3
from datetime import datetime

# Logging konfigürasyonu
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Global AWS client'ları (cold start optimizasyonu için)
s3_client = boto3.client('s3')
dynamodb_client = boto3.client('dynamodb')

def lambda_handler(event, context):
    """
    Ana Lambda handler fonksiyonu
    """
    try:
        logger.info(f"Event alındı: {json.dumps(event)}")
        
        # Event tipini belirle
        event_type = determine_event_type(event)
        
        # Event tipine göre işlem yap
        if event_type == "api_gateway":
            return handle_api_gateway(event, context)
        elif event_type == "s3":
            return handle_s3_event(event, context)
        elif event_type == "scheduled":
            return handle_scheduled_event(event, context)
        else:
            return handle_generic_event(event, context)
            
    except Exception as e:
        logger.error(f"Beklenmeyen hata: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'İç sunucu hatası',
                'message': str(e)
            })
        }

def determine_event_type(event):
    """
    Event tipini belirler
    """
    if 'httpMethod' in event:
        return "api_gateway"
    elif 'Records' in event and len(event['Records']) > 0:
        if 's3' in event['Records'][0]:
            return "s3"
        elif 'dynamodb' in event['Records'][0]:
            return "dynamodb"
    elif 'source' in event and event['source'] == 'aws.events':
        return "scheduled"
    else:
        return "generic"

def handle_api_gateway(event, context):
    """
    API Gateway event'lerini işler
    """
    http_method = event.get('httpMethod', 'GET')
    path = event.get('path', '/')
    body = event.get('body', '{}')
    
    logger.info(f"API Gateway isteği: {http_method} {path}")
    
    # Basit bir echo servisi
    response_data = {
        'message': 'AWS ZERO to YETO - Lambda API Gateway Örneği',
        'method': http_method,
        'path': path,
        'body': body,
        'timestamp': datetime.now().isoformat(),
        'remaining_time': context.get_remaining_time_in_millis()
    }
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(response_data, ensure_ascii=False)
    }

def handle_s3_event(event, context):
    """
    S3 event'lerini işler
    """
    logger.info("S3 event işleniyor...")
    
    processed_files = []
    
    for record in event['Records']:
        bucket_name = record['s3']['bucket']['name']
        object_key = record['s3']['object']['key']
        event_name = record['eventName']
        
        logger.info(f"S3 Event: {event_name} - {bucket_name}/{object_key}")
        
        # Dosya bilgilerini al
        try:
            response = s3_client.head_object(Bucket=bucket_name, Key=object_key)
            file_size = response['ContentLength']
            content_type = response.get('ContentType', 'unknown')
            
            processed_files.append({
                'bucket': bucket_name,
                'key': object_key,
                'size': file_size,
                'type': content_type,
                'event': event_name
            })
            
        except Exception as e:
            logger.error(f"Dosya bilgisi alınamadı: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'S3 event başarıyla işlendi',
            'processed_files': processed_files,
            'count': len(processed_files)
        }, ensure_ascii=False)
    }

def handle_scheduled_event(event, context):
    """
    Zamanlanmış event'leri işler
    """
    logger.info("Zamanlanmış event işleniyor...")
    
    # Basit bir zaman damgası işlemi
    current_time = datetime.now()
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Zamanlanmış görev tamamlandı',
            'timestamp': current_time.isoformat(),
            'day_of_week': current_time.strftime('%A'),
            'remaining_time': context.get_remaining_time_in_millis()
        }, ensure_ascii=False)
    }

def handle_generic_event(event, context):
    """
    Genel event'leri işler
    """
    logger.info("Genel event işleniyor...")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'AWS ZERO to YETO - Lambda Örneği',
            'event': event,
            'timestamp': datetime.now().isoformat(),
            'function_name': context.function_name,
            'function_version': context.function_version
        }, ensure_ascii=False)
    }
EOF

# Node.js Lambda fonksiyonu oluştur
print_info "Node.js Lambda fonksiyonu oluşturuluyor..."
cat > examples/nodejs/index.js << 'EOF'
const AWS = require('aws-sdk');

// Global AWS client'ları
const s3 = new AWS.S3();
const dynamodb = new AWS.DynamoDB();

exports.handler = async (event, context) => {
    console.log('Event alındı:', JSON.stringify(event, null, 2));
    
    try {
        // Event tipini belirle
        const eventType = determineEventType(event);
        
        let result;
        switch (eventType) {
            case 'api_gateway':
                result = await handleApiGateway(event, context);
                break;
            case 's3':
                result = await handleS3Event(event, context);
                break;
            case 'scheduled':
                result = await handleScheduledEvent(event, context);
                break;
            default:
                result = await handleGenericEvent(event, context);
        }
        
        return result;
        
    } catch (error) {
        console.error('Hata:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                error: 'İç sunucu hatası',
                message: error.message
            })
        };
    }
};

function determineEventType(event) {
    if (event.httpMethod) {
        return 'api_gateway';
    } else if (event.Records && event.Records.length > 0) {
        if (event.Records[0].s3) {
            return 's3';
        } else if (event.Records[0].dynamodb) {
            return 'dynamodb';
        }
    } else if (event.source === 'aws.events') {
        return 'scheduled';
    }
    return 'generic';
}

async function handleApiGateway(event, context) {
    const httpMethod = event.httpMethod || 'GET';
    const path = event.path || '/';
    const body = event.body || '{}';
    
    console.log(`API Gateway isteği: ${httpMethod} ${path}`);
    
    const responseData = {
        message: 'AWS ZERO to YETO - Lambda API Gateway Örneği (Node.js)',
        method: httpMethod,
        path: path,
        body: body,
        timestamp: new Date().toISOString(),
        remainingTime: context.getRemainingTimeInMillis()
    };
    
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify(responseData)
    };
}

async function handleS3Event(event, context) {
    console.log('S3 event işleniyor...');
    
    const processedFiles = [];
    
    for (const record of event.Records) {
        const bucketName = record.s3.bucket.name;
        const objectKey = record.s3.object.key;
        const eventName = record.eventName;
        
        console.log(`S3 Event: ${eventName} - ${bucketName}/${objectKey}`);
        
        try {
            const response = await s3.headObject({
                Bucket: bucketName,
                Key: objectKey
            }).promise();
            
            processedFiles.push({
                bucket: bucketName,
                key: objectKey,
                size: response.ContentLength,
                type: response.ContentType || 'unknown',
                event: eventName
            });
            
        } catch (error) {
            console.error(`Dosya bilgisi alınamadı: ${error.message}`);
        }
    }
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: 'S3 event başarıyla işlendi (Node.js)',
            processedFiles: processedFiles,
            count: processedFiles.length
        })
    };
}

async function handleScheduledEvent(event, context) {
    console.log('Zamanlanmış event işleniyor...');
    
    const currentTime = new Date();
    const daysOfWeek = ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi'];
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: 'Zamanlanmış görev tamamlandı (Node.js)',
            timestamp: currentTime.toISOString(),
            dayOfWeek: daysOfWeek[currentTime.getDay()],
            remainingTime: context.getRemainingTimeInMillis()
        })
    };
}

async function handleGenericEvent(event, context) {
    console.log('Genel event işleniyor...');
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: 'AWS ZERO to YETO - Lambda Örneği (Node.js)',
            event: event,
            timestamp: new Date().toISOString(),
            functionName: context.functionName,
            functionVersion: context.functionVersion
        })
    };
}
EOF

# package.json oluştur
cat > examples/nodejs/package.json << 'EOF'
{
  "name": "aws-zero-to-yeto-lambda-nodejs",
  "version": "1.0.0",
  "description": "AWS ZERO to YETO Lambda Node.js örneği",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": ["aws", "lambda", "serverless"],
  "author": "AWS ZERO to YETO",
  "license": "MIT",
  "dependencies": {
    "aws-sdk": "^2.1000.0"
  }
}
EOF

# CloudFormation template oluştur
print_info "CloudFormation template oluşturuluyor..."
cat > templates/lambda-stack.yaml << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'AWS ZERO to YETO - Lambda Örnek Stack'

Parameters:
  ProjectName:
    Type: String
    Default: 'aws-zero-to-yeto-lambda'
    Description: 'Proje adı'
  
  Environment:
    Type: String
    Default: 'dev'
    AllowedValues: ['dev', 'prod']
    Description: 'Ortam'

Resources:
  # IAM Role for Lambda
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${ProjectName}-execution-role'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        - arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
        - arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess
      Policies:
        - PolicyName: LambdaCustomPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: '*'
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                  - s3:DeleteObject
                Resource: '*'
              - Effect: Allow
                Action:
                  - dynamodb:GetItem
                  - dynamodb:PutItem
                  - dynamodb:UpdateItem
                  - dynamodb:DeleteItem
                  - dynamodb:Query
                  - dynamodb:Scan
                Resource: '*'

  # Python Lambda Function
  PythonLambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-python-function'
      Runtime: python3.9
      Handler: lambda_function.lambda_handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          import json
          def lambda_handler(event, context):
              return {
                  'statusCode': 200,
                  'body': json.dumps({
                      'message': 'AWS ZERO to YETO - Python Lambda',
                      'event': event
                  })
              }
      Timeout: 30
      MemorySize: 128
      Environment:
        Variables:
          PROJECT_NAME: !Ref ProjectName
          ENVIRONMENT: !Ref Environment

  # Node.js Lambda Function
  NodeJSLambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-nodejs-function'
      Runtime: nodejs18.x
      Handler: index.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          exports.handler = async (event, context) => {
              return {
                  statusCode: 200,
                  body: JSON.stringify({
                      message: 'AWS ZERO to YETO - Node.js Lambda',
                      event: event
                  })
              };
          };
      Timeout: 30
      MemorySize: 128
      Environment:
        Variables:
          PROJECT_NAME: !Ref ProjectName
          ENVIRONMENT: !Ref Environment

  # CloudWatch Log Group for Python
  PythonLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/lambda/${PythonLambdaFunction}'
      RetentionInDays: 7

  # CloudWatch Log Group for Node.js
  NodeJSLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/lambda/${NodeJSLambdaFunction}'
      RetentionInDays: 7

  # EventBridge Rule for Scheduled Execution
  ScheduledRule:
    Type: AWS::Events::Rule
    Properties:
      Name: !Sub '${ProjectName}-scheduled-rule'
      Description: 'Her 5 dakikada bir çalışan kural'
      ScheduleExpression: 'rate(5 minutes)'
      State: ENABLED
      Targets:
        - Arn: !GetAtt PythonLambdaFunction.Arn
          Id: 'PythonScheduledTarget'

  # Permission for EventBridge to invoke Lambda
  ScheduledPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref PythonLambdaFunction
      Action: lambda:InvokeFunction
      Principal: events.amazonaws.com
      SourceArn: !GetAtt ScheduledRule.Arn

Outputs:
  PythonFunctionName:
    Description: 'Python Lambda Function Name'
    Value: !Ref PythonLambdaFunction
    Export:
      Name: !Sub '${AWS::StackName}-PythonFunctionName'

  NodeJSFunctionName:
    Description: 'Node.js Lambda Function Name'
    Value: !Ref NodeJSLambdaFunction
    Export:
      Name: !Sub '${AWS::StackName}-NodeJSFunctionName'

  PythonFunctionArn:
    Description: 'Python Lambda Function ARN'
    Value: !GetAtt PythonLambdaFunction.Arn
    Export:
      Name: !Sub '${AWS::StackName}-PythonFunctionArn'

  NodeJSFunctionArn:
    Description: 'Node.js Lambda Function ARN'
    Value: !GetAtt NodeJSLambdaFunction.Arn
    Export:
      Name: !Sub '${AWS::StackName}-NodeJSFunctionArn'

  ScheduledRuleName:
    Description: 'Scheduled Event Rule Name'
    Value: !Ref ScheduledRule
    Export:
      Name: !Sub '${AWS::StackName}-ScheduledRuleName'
EOF

# Deployment script'i oluştur
print_info "Deployment script'i oluşturuluyor..."

# CloudFormation stack'i deploy et
print_info "CloudFormation stack deploy ediliyor..."
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://templates/lambda-stack.yaml \
    --parameters ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

print_info "Stack oluşturuluyor, lütfen bekleyin..."
aws cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME \
    --region $REGION

# Stack çıktılarını al
print_info "Stack çıktıları alınıyor..."
STACK_OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs' \
    --output json)

# Python fonksiyonunu test et
PYTHON_FUNCTION_NAME=$(echo $STACK_OUTPUTS | jq -r '.[] | select(.OutputKey=="PythonFunctionName") | .OutputValue')
print_info "Python Lambda fonksiyonu test ediliyor: $PYTHON_FUNCTION_NAME"

# Test event oluştur
cat > test-event.json << 'EOF'
{
    "name": "AWS ZERO to YETO",
    "message": "Merhaba Lambda!"
}
EOF

# Fonksiyonu test et
aws lambda invoke \
    --function-name $PYTHON_FUNCTION_NAME \
    --payload file://test-event.json \
    --region $REGION \
    response.json

print_info "Test sonucu:"
cat response.json | jq '.'

# Deployment bilgilerini kaydet
cat > deployment-info.txt << EOF
AWS ZERO to YETO - Lambda Deployment Bilgileri
==============================================

Deployment Tarihi: $(date)
Stack Adı: $STACK_NAME
Bölge: $REGION
Proje: $PROJECT_NAME

Oluşturulan Kaynaklar:
- Python Lambda Function: $PYTHON_FUNCTION_NAME
- Node.js Lambda Function: $(echo $STACK_OUTPUTS | jq -r '.[] | select(.OutputKey=="NodeJSFunctionName") | .OutputValue')
- IAM Execution Role
- CloudWatch Log Groups
- EventBridge Scheduled Rule

Test Komutları:
# Python fonksiyonunu test et
aws lambda invoke --function-name $PYTHON_FUNCTION_NAME --payload '{"test":"data"}' response.json

# Logları görüntüle
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/$PYTHON_FUNCTION_NAME"

# Fonksiyon bilgilerini al
aws lambda get-function --function-name $PYTHON_FUNCTION_NAME

Temizlik için:
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
EOF

# Temizlik
rm -f test-event.json response.json

print_success "🎉 Lambda deployment tamamlandı!"
print_info "Stack: $STACK_NAME"
print_info "Python Function: $PYTHON_FUNCTION_NAME"
print_info "Deployment bilgileri: deployment-info.txt dosyasında saklandı"

print_warning "⚠️  Bu stack ücretli kaynaklar içerir. Kullanmadığınızda silmeyi unutmayın."

echo ""
print_info "Test komutları:"
echo "  aws lambda invoke --function-name $PYTHON_FUNCTION_NAME --payload '{\"test\":\"data\"}' response.json"
echo "  aws logs describe-log-groups --log-group-name-prefix \"/aws/lambda/$PYTHON_FUNCTION_NAME\""echo "  aws lambda get-function --function-name $PYTHON_FUNCTION_NAME"

