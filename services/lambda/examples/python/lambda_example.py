#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AWS ZERO to YETO - Lambda Python Örneği
Bu dosya Lambda fonksiyonlarının temel kullanımını gösterir
"""

import json
import boto3
import logging
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

# Test fonksiyonu (local development için)
def test_lambda():
    """
    Lambda fonksiyonunu test eder
    """
    # Test event'leri
    test_events = [
        {
            'name': 'Test Event',
            'message': 'Merhaba Lambda!'
        },
        {
            'httpMethod': 'POST',
            'path': '/test',
            'body': '{"test": "data"}'
        },
        {
            'source': 'aws.events',
            'detail-type': 'Scheduled Event'
        }
    ]
    
    print("🧪 Lambda Test Başlatılıyor...")
    
    for i, event in enumerate(test_events, 1):
        print(f"\n--- Test {i} ---")
        print(f"Event: {json.dumps(event, indent=2)}")
        
        # Mock context
        class MockContext:
            def __init__(self):
                self.function_name = 'test-function'
                self.function_version = '$LATEST'
            
            def get_remaining_time_in_millis(self):
                return 30000
        
        context = MockContext()
        
        # Fonksiyonu çağır
        result = lambda_handler(event, context)
        print(f"Sonuç: {json.dumps(result, indent=2, ensure_ascii=False)}")

if __name__ == "__main__":
    test_lambda()
