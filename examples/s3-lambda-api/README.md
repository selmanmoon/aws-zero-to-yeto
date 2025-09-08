# S3 + Lambda + API Gateway - Serverless Dosya İşleme

## 📖 Proje Açıklaması

Bu proje, S3'e yüklenen dosyaların Lambda ile otomatik işlenmesini ve API Gateway üzerinden sonuçlara erişimi gösterir. Tamamen serverless bir mimari kullanır.

**Senaryo**: Kullanıcı S3'e resim yükler → Lambda otomatik tetiklenir → Resim boyutunu analiz eder → Sonuçları DynamoDB'ye kaydeder → API ile sonuçları sorgulanabilir.

## 🏗️ Mimari

```
Kullanıcı → S3 (Resim Upload) → Lambda (Trigger) → DynamoDB (Sonuç)
                                     ↓
API Gateway ← Lambda (Query) ← DynamoDB (Veri Okuma)
```

## 🚀 Kullanılan Servisler

- **S3**: Dosya depolama ve event trigger
- **Lambda**: Serverless işleme
- **API Gateway**: REST API endpoint
- **DynamoDB**: Sonuç verileri (Free Tier: 25GB)

## 💰 Maliyet (Free Tier)

- S3: 5GB ücretsiz
- Lambda: 1M istek ücretsiz
- API Gateway: 1M istek ücretsiz
- DynamoDB: 25GB ücretsiz

**Toplam**: Aylık binlerce işlem tamamen ücretsiz!

## 🔧 Özellikler

- ✅ Otomatik dosya işleme
- ✅ REST API ile sonuç sorgulama  
- ✅ Real-time event processing
- ✅ Tamamen serverless
- ✅ Auto-scaling (yük artışında otomatik ölçeklenir)

## 📦 Deploy Etme

```bash
cd examples/s3-lambda-api
./deploy.sh
```

## 📋 Test Senaryoları

1. **Dosya Upload Test**
   ```bash
   aws s3 cp test-image.jpg s3://YOUR-BUCKET/uploads/
   ```

2. **API Test**
   ```bash
   curl https://YOUR-API-GATEWAY-URL/files
   ```

3. **Lambda Logs**
   ```bash
   aws logs tail /aws/lambda/s3-processor --follow
   ```

## 🎓 Deploy Sonrası Öğrenme Adımları

### ✅ Ne Öğrendiniz?
- **S3 Event Triggers**: Dosya yüklendiğinde otomatik tetikleme
- **Lambda Fonksiyonları**: Serverless kod çalıştırma
- **API Gateway**: REST API oluşturma
- **Event-Driven Architecture**: Olay tabanlı mimari

### 🔧 Şimdi Bunları Deneyebilirsiniz:

#### 1. Farklı Dosya Türleri Test Edin
```bash
# Resim dosyası yükle
aws s3 cp test-image.jpg s3://YOUR-BUCKET-NAME/uploads/

# PDF dosyası yükle  
aws s3 cp document.pdf s3://YOUR-BUCKET-NAME/uploads/

# JSON dosyası yükle
echo '{"test": "data"}' > test.json
aws s3 cp test.json s3://YOUR-BUCKET-NAME/uploads/
```

#### 2. API Endpoint'lerini Keşfedin
```bash
# Tüm dosyaları listele
curl https://YOUR-API-ID.execute-api.eu-west-1.amazonaws.com/prod/files

# Belirli bir dosya hakkında bilgi al
curl https://YOUR-API-ID.execute-api.eu-west-1.amazonaws.com/prod/files/test-image.jpg

# Dosya istatistiklerini gör
curl https://YOUR-API-ID.execute-api.eu-west-1.amazonaws.com/prod/stats
```

#### 3. Lambda Fonksiyonunu İzleyin
```bash
# Canlı logları takip et
aws logs tail /aws/lambda/YOUR-LAMBDA-FUNCTION-NAME --follow

# Lambda metriklerini gör
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=YOUR-LAMBDA-FUNCTION-NAME \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum
```

#### 4. S3 Bucket'ını İnceleyin
```bash
# Bucket içeriğini listele
aws s3 ls s3://YOUR-BUCKET-NAME/

# Yüklenen dosyaları gör
aws s3 ls s3://YOUR-BUCKET-NAME/uploads/

# İşlenmiş dosyaları gör
aws s3 ls s3://YOUR-BUCKET-NAME/processed/
```

#### 5. DynamoDB Verilerini Kontrol Edin
```bash
# Tüm dosya kayıtlarını gör
aws dynamodb scan --table-name YOUR-TABLE-NAME

# Belirli bir dosya hakkında bilgi al
aws dynamodb get-item \
    --table-name YOUR-TABLE-NAME \
    --key '{"filename": {"S": "test-image.jpg"}}'
```

### 🚀 Sonraki Adımlar
1. **Dosya İşleme Geliştirin**: Lambda'da resim boyutlandırma ekleyin
2. **API Geliştirin**: Dosya silme, güncelleme endpoint'leri ekleyin
3. **Monitoring Ekleyin**: CloudWatch alarmları kurun
4. **Frontend Ekleyin**: Web arayüzü oluşturun
