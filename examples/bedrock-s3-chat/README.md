# Bedrock + S3 - AI Chatbot

## 📖 Proje Açıklaması

Bu proje, Amazon Bedrock'un Claude 3 modelini kullanarak basit bir AI chatbot oluşturur. Konuşma geçmişi S3'te saklanır ve Lambda fonksiyonu ile API Gateway üzerinden erişilebilir.

**Senaryo**: Kullanıcı API'ye mesaj gönderir → Lambda Bedrock'a iletir → Claude 3 cevap üretir → Konuşma S3'e kaydedilir → Kullanıcıya cevap döndürülür.

## 🏗️ Mimari

```
Kullanıcı → API Gateway → Lambda → Bedrock (Claude 3)
                          ↓            ↓
                       S3 (Chat History) ← JSON Files
```

## 🚀 Kullanılan Servisler

- **Bedrock**: Claude 3 Sonnet AI modeli
- **Lambda**: API işleme ve orchestration
- **S3**: Konuşma geçmişi depolama
- **API Gateway**: REST API endpoint

## 💰 Maliyet (Free Tier)

- Bedrock: 5M input + 5M output token ücretsiz
- Lambda: 1M istek ücretsiz
- S3: 5GB ücretsiz
- API Gateway: 1M istek ücretsiz

**Toplam**: Binlerce AI konuşması tamamen ücretsiz!

## 🔧 Özellikler

- ✅ Claude 3 Sonnet AI modeli
- ✅ Türkçe konuşma desteği
- ✅ Konuşma geçmişi saklama
- ✅ JSON API yanıtları
- ✅ CORS desteği (web uygulamaları için)

## 📦 Deploy Etme

```bash
cd examples/bedrock-s3-chat
./deploy.sh
```

## 📋 Test Senaryoları

1. **Basit Soru**
   ```bash
   curl -X POST "YOUR-API-URL/chat" \
        -H "Content-Type: application/json" \
        -d '{"message": "Merhaba, AWS nedir?"}'
   ```

2. **Teknik Soru**
   ```bash
   curl -X POST "YOUR-API-URL/chat" \
        -d '{"message": "Lambda fonksiyonu nasıl çalışır?"}'
   ```

3. **Konuşma Geçmişi**
   ```bash
   curl "YOUR-API-URL/chat/history"
   ```

## 🎓 Deploy Sonrası Öğrenme Adımları

### ✅ Ne Öğrendiniz?
- **Amazon Bedrock**: Generative AI modeli kullanımı
- **Claude 3 Sonnet**: Gelişmiş AI modeli
- **Lambda AI Integration**: AI ile serverless entegrasyon
- **S3 Data Storage**: Konuşma geçmişi saklama
- **API Gateway**: RESTful API oluşturma

### 🔧 Şimdi Bunları Deneyebilirsiniz:

#### 1. Farklı AI Soruları Test Edin
```bash
# Basit sohbet
curl -X POST "YOUR-API-URL/chat" \
     -H "Content-Type: application/json" \
     -d '{"message": "Merhaba, nasılsın?"}'

# Teknik soru
curl -X POST "YOUR-API-URL/chat" \
     -d '{"message": "Docker container nedir ve nasıl çalışır?"}'

# Kod yazma
curl -X POST "YOUR-API-URL/chat" \
     -d '{"message": "Python ile basit bir web scraper yaz"}'

# Matematik problemi
curl -X POST "YOUR-API-URL/chat" \
     -d '{"message": "2+2 kaç eder ve neden?"}'
```

#### 2. Konuşma Geçmişini İnceleyin
```bash
# Tüm konuşma geçmişini al
curl "YOUR-API-URL/chat/history"

# Belirli bir konuşmayı al
curl "YOUR-API-URL/chat/history?session_id=YOUR-SESSION-ID"

# Konuşma sayısını öğren
curl "YOUR-API-URL/chat/stats"
```

#### 3. S3'teki Verileri Kontrol Edin
```bash
# Chat verilerini listele
aws s3 ls s3://YOUR-BUCKET-NAME/

# Belirli bir konuşma dosyasını indir
aws s3 cp s3://YOUR-BUCKET-NAME/session_123.json .

# Dosya içeriğini gör
cat session_123.json | jq '.'

# Tüm konuşma dosyalarını listele
aws s3 ls s3://YOUR-BUCKET-NAME/ --recursive
```

#### 4. Lambda Fonksiyonunu İzleyin
```bash
# Canlı logları takip et
aws logs tail /aws/lambda/YOUR-LAMBDA-FUNCTION-NAME --follow

# Lambda metriklerini gör
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Duration \
    --dimensions Name=FunctionName,Value=YOUR-LAMBDA-FUNCTION-NAME \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average
```

#### 5. Bedrock Modelini Test Edin
```bash
# Doğrudan Bedrock API'sini test et
aws bedrock-runtime invoke-model \
    --model-id anthropic.claude-3-sonnet-20240229-v1:0 \
    --body '{"prompt": "Merhaba, AWS hakkında bilgi ver", "max_tokens": 100}' \
    --cli-binary-format raw-in-base64-out \
    response.json

# Yanıtı gör
cat response.json | jq '.'
```

#### 6. API Gateway Metriklerini İzleyin
```bash
# API çağrı sayısını gör
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name Count \
    --dimensions Name=ApiName,Value=YOUR-API-NAME \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum

# API latency'yi kontrol et
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name Latency \
    --dimensions Name=ApiName,Value=YOUR-API-NAME \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average
```

#### 7. Farklı AI Modellerini Deneyin
```bash
# Claude 3 Haiku (daha hızlı)
aws bedrock-runtime invoke-model \
    --model-id anthropic.claude-3-haiku-20240307-v1:0 \
    --body '{"prompt": "Kısa bir şiir yaz", "max_tokens": 50}' \
    --cli-binary-format raw-in-base64-out \
    haiku_response.json

# Claude 3 Opus (daha güçlü)
aws bedrock-runtime invoke-model \
    --model-id anthropic.claude-3-opus-20240229-v1:0 \
    --body '{"prompt": "Karmaşık bir problem çöz", "max_tokens": 200}' \
    --cli-binary-format raw-in-base64-out \
    opus_response.json
```

### 🚀 Sonraki Adımlar
1. **Web Arayüzü Ekleyin**: HTML/CSS/JS ile chat arayüzü
2. **Farklı Modeller**: Llama, Titan gibi diğer AI modellerini deneyin
3. **Context Management**: Uzun konuşmalar için context yönetimi
4. **Streaming Responses**: Gerçek zamanlı yanıt akışı
5. **Multi-language Support**: Çoklu dil desteği ekleyin
6. **User Authentication**: Kullanıcı kimlik doğrulama sistemi
