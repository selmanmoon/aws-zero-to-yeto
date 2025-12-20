# AWS Lambda

## 📖 Servis Hakkında

AWS Lambda, serverless computing'in kalbi olan bir servistir. Kodunuzu sunucu yönetmeden çalıştırmanızı sağlar. Sadece kodunuz çalıştığında ödeme yaparsınız.

### 🎯 Lambda'nın Temel Özellikleri

- **Serverless**: Sunucu yönetimi yok
- **Otomatik Ölçeklendirme**: Yük artışında otomatik olarak ölçeklenir
- **Event-Driven**: Diğer AWS servislerinden tetiklenebilir
- **Maliyet Etkin**: Sadece çalışma süresi kadar ödeme
- **Çoklu Dil Desteği**: Python, Node.js, Java, Go, .NET, Ruby

### 🏗️ Lambda Mimarisi

```
Event Source (Tetikleyici)
    ↓
Lambda Function (Fonksiyon)
    ↓
Execution Environment (Çalışma Ortamı)
    ↓
Response (Yanıt)
```

## ⚡ Runtime'lar ve Desteklenen Diller

| Dil | Runtime | Versiyon |
|-----|---------|----------|
| **Python** | python3.9 | 3.9, 3.10, 3.11 |
| **Node.js** | nodejs18.x | 18.x, 20.x |
| **Java** | java11 | 8, 11, 17 |
| **Go** | provided.al2 | 1.x |
| **.NET** | dotnet6 | 6.0, 8.0 |
| **Ruby** | ruby3.2 | 3.2 |

## 💰 Maliyet Hesaplama

### Fiyatlandırma Modeli
- **İstek Başına**: $0.20/1M istek
- **GB-saniye**: $0.0000166667/GB-saniye
- **Bellek**: 128MB - 10GB arası

### Örnek Hesaplama
```
1M istek × $0.20 = $0.20
400,000 GB-saniye × $0.0000166667 = $6.67
Toplam: $6.87/ay
```

## 🔧 Lambda Fonksiyon Yapısı

### Python Örneği
```python
import json

def lambda_handler(event, context):
    """
    Lambda fonksiyon handler'ı
    """
    # Event'ten gelen veriyi işle
    name = event.get('name', 'Dünya')
    
    # İşlemi gerçekleştir
    message = f"Merhaba {name}!"
    
    # Yanıt döndür
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': message,
            'timestamp': context.get_remaining_time_in_millis()
        })
    }
```

### Node.js Örneği
```javascript
exports.handler = async (event, context) => {
    // Event'ten gelen veriyi işle
    const name = event.name || 'Dünya';
    
    // İşlemi gerçekleştir
    const message = `Merhaba ${name}!`;
    
    // Yanıt döndür
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: message,
            timestamp: context.getRemainingTimeInMillis()
        })
    };
};
```

## 🎯 Event Sources (Tetikleyiciler)

### 1. API Gateway
```json
{
    "httpMethod": "POST",
    "path": "/users",
    "body": "{\"name\":\"Ahmet\",\"email\":\"ahmet@example.com\"}"
}
```

### 2. S3 Events
```json
{
    "Records": [
        {
            "eventName": "ObjectCreated:Put",
            "s3": {
                "bucket": {"name": "my-bucket"},
                "object": {"key": "uploads/image.jpg"}
            }
        }
    ]
}
```

### 3. DynamoDB Streams
```json
{
    "Records": [
        {
            "eventName": "INSERT",
            "dynamodb": {
                "NewImage": {
                    "id": {"S": "123"},
                    "name": {"S": "Ahmet"}
                }
            }
        }
    ]
}
```

### 4. CloudWatch Events
```json
{
    "version": "0",
    "id": "12345678-1234-1234-1234-123456789012",
    "detail-type": "Scheduled Event",
    "source": "aws.events",
    "time": "2023-01-01T00:00:00Z"
}
```

## 🔐 Güvenlik ve İzinler

### IAM Role Örneği
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::my-bucket/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
```

## 📊 Monitoring ve Logging

### CloudWatch Logs
```python
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Event alındı: {event}")
    
    # İşlem yap
    result = process_data(event)
    
    logger.info(f"İşlem tamamlandı: {result}")
    return result
```

### CloudWatch Metrics
- **Invocation Count**: Çağrılma sayısı
- **Duration**: Çalışma süresi
- **Error Count**: Hata sayısı
- **Throttle Count**: Kısıtlama sayısı

## 🚀 Best Practices

### 1. Cold Start Optimizasyonu
```python
# Global değişkenler kullan
import boto3

# Global olarak tanımla
s3_client = boto3.client('s3')
dynamodb_client = boto3.client('dynamodb')

def lambda_handler(event, context):
    # Fonksiyon içinde tekrar oluşturma
    pass
```

### 2. Bellek Optimizasyonu
- İhtiyacınız kadar bellek ayarlayın
- Gereksiz kütüphaneleri kaldırın
- Layer'ları kullanın

### 3. Error Handling
```python
import json
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    try:
        # Ana işlem
        result = process_data(event)
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
    except ClientError as e:
        logger.error(f"AWS hatası: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'AWS servis hatası'})
        }
    except Exception as e:
        logger.error(f"Beklenmeyen hata: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'İç sunucu hatası'})
        }
```

### 4. Timeout Yönetimi
```python
def lambda_handler(event, context):
    # Kalan süreyi kontrol et
    if context.get_remaining_time_in_millis() < 10000:  # 10 saniye
        logger.warning("Zaman azalıyor, işlemi sonlandır")
        return {'statusCode': 408, 'body': 'Timeout'}
    
    # İşlemi gerçekleştir
    pass
```
▶️ Çalıştırma Adımları
cd services        # Servis dizinine geç
cd lambda             # lambda dizinine geç
chmod +x deploy.sh cleanup.sh
./deploy.sh        # Deploy işlemi
./cleanup.sh       # Cleanup işlemi
 
```

## 🧪 Test Senaryoları

Bu klasörde bulunan örnekler ile test edebileceğiniz senaryolar:

1. **Temel Lambda Fonksiyonu**
   - Basit "Hello World" örneği
   - Event ve context kullanımı

2. **S3 Event Handler**
   - Dosya yüklendiğinde tetiklenen fonksiyon
   - Resim işleme örneği

3. **API Gateway Entegrasyonu**
   - REST API endpoint'i
   - JSON request/response işleme

4. **DynamoDB Stream Handler**
   - Veritabanı değişikliklerini dinleme
   - Real-time veri işleme

5. **Scheduled Function**
   - Zamanlanmış görevler
   - Cron expression kullanımı

## 📚 Öğrenme Kaynakları

- [AWS Lambda Dokümantasyonu](https://docs.aws.amazon.com/lambda/)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Lambda Pricing](https://aws.amazon.com/lambda/pricing/)

## 🎯 Sonraki Adımlar

Lambda'yı öğrendikten sonra şu servisleri keşfedin:
- **API Gateway** - REST API'ler oluşturma
- **EventBridge** - Event-driven mimari
- **Step Functions** - Workflow orchestration
- **SQS/SNS** - Message queuing ve notification
