#!/usr/bin/env python3
"""
AWS ZERO to YETO - DynamoDB Python Örneği
"""

import boto3
import json
import time
from datetime import datetime

class DynamoDBManager:
    def __init__(self, region='eu-west-1'):
        self.dynamodb = boto3.resource('dynamodb', region_name=region)
        self.client = boto3.client('dynamodb', region_name=region)
    
    def create_table(self, table_name):
        """DynamoDB table oluştur"""
        try:
            print(f"🗄️ DynamoDB table oluşturuluyor: {table_name}")
            
            table = self.dynamodb.create_table(
                TableName=table_name,
                KeySchema=[
                    {'AttributeName': 'id', 'KeyType': 'HASH'},
                    {'AttributeName': 'timestamp', 'KeyType': 'RANGE'}
                ],
                AttributeDefinitions=[
                    {'AttributeName': 'id', 'AttributeType': 'S'},
                    {'AttributeName': 'timestamp', 'AttributeType': 'N'}
                ],
                BillingMode='PAY_PER_REQUEST'
            )
            
            table.wait_until_exists()
            print(f"✅ Table oluşturuldu: {table_name}")
            return table
        except Exception as e:
            print(f"❌ Table oluşturma hatası: {str(e)}")
            return None
    
    def put_item(self, table_name, item):
        """Veri ekle"""
        try:
            table = self.dynamodb.Table(table_name)
            response = table.put_item(Item=item)
            print(f"✅ Veri eklendi: {item.get('id', 'unknown')}")
            return response
        except Exception as e:
            print(f"❌ Veri ekleme hatası: {str(e)}")
            return None
    
    def get_item(self, table_name, key):
        """Veri oku"""
        try:
            table = self.dynamodb.Table(table_name)
            response = table.get_item(Key=key)
            
            if 'Item' in response:
                print(f"✅ Veri bulundu: {response['Item']}")
                return response['Item']
            else:
                print("📭 Veri bulunamadı")
                return None
        except Exception as e:
            print(f"❌ Veri okuma hatası: {str(e)}")
            return None

def main():
    """Ana fonksiyon"""
    print("🗄️ AWS ZERO to YETO - DynamoDB Python Örnekleri")
    print("=" * 50)
    
    db = DynamoDBManager()
    table_name = f"aws-zero-to-yeto-demo-{int(time.time())}"
    
    try:
        # 1. Table oluştur
        table = db.create_table(table_name)
        if not table:
            return
        
        # 2. Veri ekle
        print("\n📝 Veri Ekleme")
        users = [
            {
                'id': 'user-001',
                'timestamp': int(time.time()),
                'name': 'Ahmet Yılmaz',
                'email': 'ahmet@example.com',
                'age': 28
            },
            {
                'id': 'user-002', 
                'timestamp': int(time.time()) + 1,
                'name': 'Ayşe Kaya',
                'email': 'ayse@example.com',
                'age': 32
            }
        ]
        
        for user in users:
            db.put_item(table_name, user)
        
        # 3. Veri oku
        print("\n📖 Veri Okuma")
        key = {'id': 'user-001', 'timestamp': users[0]['timestamp']}
        item = db.get_item(table_name, key)
        
        # 4. Scan (tüm veriler)
        print("\n🔍 Tüm Veriler")
        table = db.dynamodb.Table(table_name)
        response = table.scan()
        
        print(f"📊 Toplam {response['Count']} kayıt:")
        for item in response['Items']:
            print(f"  👤 {item['name']} ({item['email']})")
        
        print("\n🎉 DynamoDB demo tamamlandı!")
        print(f"⚠️ Table'ı silmeyi unutmayın: {table_name}")
        
    except Exception as e:
        print(f"❌ Beklenmeyen hata: {str(e)}")

if __name__ == "__main__":
    main()
