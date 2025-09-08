# Amazon DynamoDB

## 📖 Servis Hakkında

Amazon DynamoDB, AWS'nin tam yönetilen NoSQL veritabanı servisidir. Hızlı, ölçeklenebilir ve güvenilirdir. SQL yerine key-value ve document store modeli kullanır.

### 🎯 DynamoDB'nin Temel Özellikleri

- **Serverless**: Sunucu yönetimi yok
- **Otomatik Ölçeklendirme**: Yük artışında otomatik genişleme  
- **Tek Haneli Milisaniye**: Çok hızlı yanıt süreleri
- **Global Tables**: Çok bölgeli replikasyon
- **ACID Transactions**: Güvenilir veri işleme

## 💰 Free Tier Limitleri
- **25GB** depolama
- **25 WCU** (Write Capacity Units)
- **25 RCU** (Read Capacity Units)
- **2.5M** stream read istekleri

## 🔧 Temel Kavramlar

### Table Yapısı
```python
table_structure = {
    'TableName': 'Users',
    'KeySchema': [
        {
            'AttributeName': 'user_id',
            'KeyType': 'HASH'  # Partition Key
        },
        {
            'AttributeName': 'created_at', 
            'KeyType': 'RANGE'  # Sort Key
        }
    ],
    'AttributeDefinitions': [
        {
            'AttributeName': 'user_id',
            'AttributeType': 'S'  # String
        },
        {
            'AttributeName': 'created_at',
            'AttributeType': 'N'  # Number
        }
    ]
}
```

### CRUD İşlemleri
```python
import boto3

dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')
table = dynamodb.Table('Users')

# Create - Veri ekleme
table.put_item(
    Item={
        'user_id': 'user123',
        'name': 'Ahmet Yılmaz',
        'email': 'ahmet@example.com',
        'age': 28,
        'created_at': 1640995200
    }
)

# Read - Veri okuma
response = table.get_item(
    Key={
        'user_id': 'user123',
        'created_at': 1640995200
    }
)

# Update - Veri güncelleme
table.update_item(
    Key={'user_id': 'user123', 'created_at': 1640995200},
    UpdateExpression='SET age = :age, email = :email',
    ExpressionAttributeValues={
        ':age': 29,
        ':email': 'ahmet.new@example.com'
    }
)

# Delete - Veri silme
table.delete_item(
    Key={
        'user_id': 'user123',
        'created_at': 1640995200
    }
)
```

## 🧪 Test Senaryoları

1. **User Management System**
2. **E-commerce Product Catalog** 
3. **Real-time Chat Application**
4. **IoT Data Storage**
5. **Gaming Leaderboards**

## 📚 Öğrenme Kaynakları

- [DynamoDB Dokümantasyonu](https://docs.aws.amazon.com/dynamodb/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
