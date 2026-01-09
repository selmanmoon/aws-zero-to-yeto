# SQS + SNS Notification Service - Mesaj Kuyruğu ve Bildirim Sistemi

## 📖 Proje Açıklaması

Bu proje, AWS SQS (Simple Queue Service) ve SNS (Simple Notification Service) kullanarak asenkron bir bildirim sistemi oluşturur. Mesajlar kuyruğa eklenir, Lambda ile işlenir ve email/SMS ile gönderilir.

**Senaryo**: Kullanıcı API'ye bildirim isteği gönderir → Mesaj SQS kuyruğuna eklenir → Consumer Lambda mesajı alır → SNS ile bildirim gönderir → DynamoDB'ye loglanır.

## 🏗️ Mimari

```
Kullanıcı → API Gateway → Producer Lambda → SQS (Queue)
                                               ↓
                                    Consumer Lambda (Trigger)
                                               ↓
                                    ┌──────────┴──────────┐
                                    ↓                     ↓
                              SNS (Topic)           DynamoDB (Log)
                                    ↓
                            Email / SMS Bildirimi
```

## 🚀 Kullanılan Servisler

| Servis          | Açıklama                           | Free Tier                 |
| --------------- | ---------------------------------- | ------------------------- |
| **SQS**         | Mesaj kuyruğu (async işleme)       | 1M istek/ay ücretsiz      |
| **SNS**         | Email/SMS bildirimi                | 1M push, 100 SMS ücretsiz |
| **Lambda**      | Producer ve Consumer fonksiyonları | 1M istek/ay ücretsiz      |
| **API Gateway** | REST API endpoint                  | 1M istek/ay ücretsiz      |
| **DynamoDB**    | Mesaj logları                      | 25GB ücretsiz             |

## 💰 Maliyet

**Tamamen Free Tier içinde!**

- SQS: İlk 1 milyon istek ücretsiz
- SNS: İlk 1 milyon push bildirimi ücretsiz
- Lambda: İlk 1 milyon istek ücretsiz
- API Gateway: İlk 1 milyon istek ücretsiz
- DynamoDB: 25GB depolama ücretsiz

## 🔧 Özellikler

- ✅ Asenkron mesaj işleme (decoupling)
- ✅ Email/SMS bildirimi
- ✅ Otomatik retry mekanizması
- ✅ Dead Letter Queue desteği
- ✅ Mesaj loglama (DynamoDB)
- ✅ RESTful API
- ✅ CORS desteği

## 📦 Deploy Etme

```bash
cd examples/sqs-sns-notification
chmod +x deploy.sh
./deploy.sh
```

## 📋 Kullanım

### 1. Email Aboneliği Ekle

Deploy sonrası verilen SNS Topic ARN'ını kullanarak email aboneliği ekleyin:

```bash
aws sns subscribe \
    --topic-arn YOUR_TOPIC_ARN \
    --protocol email \
    --notification-endpoint your-email@example.com \
    --region eu-west-1
```

> ⚠️ **Önemli**: Email'inize gelen doğrulama linkine tıklamayı unutmayın!

### 2. Bildirim Gönder

```bash
curl -X POST 'YOUR_API_URL' \
     -H 'Content-Type: application/json' \
     -d '{
         "recipient": "test@example.com",
         "subject": "Test Bildirimi",
         "message": "Merhaba AWS! Bu bir test mesajıdır."
     }'
```

### 3. Yanıt Örneği

```json
{
  "success": true,
  "message_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "queued",
  "info": "Mesaj başarıyla kuyruğa eklendi"
}
```

## 🧪 Test Senaryoları

### 1. Basit Bildirim

```bash
curl -X POST 'YOUR_API_URL' \
     -H 'Content-Type: application/json' \
     -d '{"subject": "Merhaba", "message": "Test mesajı"}'
```

### 2. Çoklu Bildirim (Yük Testi)

```bash
for i in {1..10}; do
    curl -X POST 'YOUR_API_URL' \
         -H 'Content-Type: application/json' \
         -d "{\"subject\": \"Test $i\", \"message\": \"Mesaj numarası: $i\"}"
    echo ""
done
```

### 3. SQS Kuyruğunu Kontrol Et

```bash
aws sqs get-queue-attributes \
    --queue-url YOUR_QUEUE_URL \
    --attribute-names ApproximateNumberOfMessages \
    --region eu-west-1
```

### 4. DynamoDB Loglarını Kontrol Et

```bash
aws dynamodb scan --table-name YOUR_TABLE_NAME --region eu-west-1
```

## 🎓 Deploy Sonrası Öğrenme Adımları

### ✅ Ne Öğrendiniz?

- **SQS (Simple Queue Service)**: Mesaj kuyruğu ve asenkron işleme
- **SNS (Simple Notification Service)**: Push bildirimleri ve pub/sub pattern
- **Producer-Consumer Pattern**: Microservices mimarisi
- **Event-Driven Architecture**: Lambda trigger'ları
- **Decoupling**: Servislerin birbirinden bağımsız çalışması

### 🔧 Şimdi Bunları Deneyebilirsiniz

#### 1. SQS Metriklerini İzleyin

```bash
# Kuyrukta bekleyen mesaj sayısı
aws sqs get-queue-attributes \
    --queue-url YOUR_QUEUE_URL \
    --attribute-names All \
    --region eu-west-1

# CloudWatch'tan SQS metrikleri
aws cloudwatch get-metric-statistics \
    --namespace AWS/SQS \
    --metric-name NumberOfMessagesSent \
    --dimensions Name=QueueName,Value=YOUR_QUEUE_NAME \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum \
    --region eu-west-1
```

#### 2. Lambda Loglarını İnceleyin

```bash
# Producer Lambda logları
aws logs tail /aws/lambda/YOUR_PRODUCER_FUNCTION --follow --region eu-west-1

# Consumer Lambda logları
aws logs tail /aws/lambda/YOUR_CONSUMER_FUNCTION --follow --region eu-west-1
```

#### 3. SNS Subscription Listesini Görün

```bash
aws sns list-subscriptions-by-topic \
    --topic-arn YOUR_TOPIC_ARN \
    --region eu-west-1
```

#### 4. Mesaj Durumlarını Kontrol Edin

```bash
# Tüm mesajları listele
aws dynamodb scan --table-name YOUR_TABLE_NAME --region eu-west-1

# Sadece "sent" durumundaki mesajları filtrele
aws dynamodb scan \
    --table-name YOUR_TABLE_NAME \
    --filter-expression "#s = :status" \
    --expression-attribute-names '{"#s": "status"}' \
    --expression-attribute-values '{":status": {"S": "sent"}}' \
    --region eu-west-1
```

#### 5. Farklı Bildirim Türleri Deneyin

```bash
# SMS bildirimi (telefon numarası ekleyin)
aws sns subscribe \
    --topic-arn YOUR_TOPIC_ARN \
    --protocol sms \
    --notification-endpoint +901234567890 \
    --region eu-west-1

# HTTP endpoint (webhook)
aws sns subscribe \
    --topic-arn YOUR_TOPIC_ARN \
    --protocol https \
    --notification-endpoint https://your-webhook-url.com/notify \
    --region eu-west-1
```

## 🔄 Consumer-Producer Pattern Açıklaması

```
┌─────────────────────────────────────────────────────────────┐
│                    PRODUCER LAMBDA                          │
│  1. API Gateway'den istek alır                              │
│  2. Mesajı hazırlar                                         │
│  3. SQS kuyruğuna gönderir                                  │
│  4. DynamoDB'ye "queued" durumunda loglar                   │
│  5. Kullanıcıya response döner                              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      SQS QUEUE                              │
│  • Mesajları güvenli şekilde saklar                         │
│  • Retry mekanizması sağlar                                 │
│  • Consumer hazır olunca mesajı iletir                      │
│  • FIFO veya Standard mode destekler                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    CONSUMER LAMBDA                          │
│  1. SQS'ten mesaj alır (trigger)                            │
│  2. Mesajı parse eder                                       │
│  3. SNS'e bildirim gönderir                                 │
│  4. DynamoDB'yi "sent" olarak günceller                     │
│  5. Mesajı kuyruktan siler                                  │
└─────────────────────────────────────────────────────────────┘
```

## ⚠️ Dikkat Edilmesi Gerekenler

1. **Email Doğrulama**: SNS email subscription'ı ekledikten sonra gelen doğrulama emailini onaylamanız gerekir.

2. **Dead Letter Queue**: Production ortamında başarısız mesajlar için DLQ kullanın.

3. **Visibility Timeout**: Consumer işleme süresi visibility timeout'tan uzunsa, mesaj tekrar işlenebilir.

4. **Idempotency**: Consumer fonksiyonu idempotent olmalı (aynı mesaj birden fazla işlense bile sorun olmamalı).

## 🚀 Sonraki Adımlar

1. **Dead Letter Queue Ekleyin**: Başarısız mesajları yakalamak için
2. **FIFO Queue Kullanın**: Mesaj sıralaması önemliyse
3. **Message Filtering**: SNS'te mesaj filtreleme ekleyin
4. **Web Arayüzü**: Bildirim gönderme için basit bir web form
5. **Scheduled Messages**: EventBridge ile zamanlanmış bildirimler
6. **Multi-Region**: Cross-region SQS/SNS entegrasyonu

## 🧹 Temizlik

Tüm kaynakları silmek için:

```bash
./cleanup.sh
```

## 📚 Kaynaklar

- [AWS SQS Developer Guide](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/)
- [AWS SNS Developer Guide](https://docs.aws.amazon.com/sns/latest/dg/)
- [Lambda with SQS](https://docs.aws.amazon.com/lambda/latest/dg/with-sqs.html)
- [SQS Best Practices](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-best-practices.html)
