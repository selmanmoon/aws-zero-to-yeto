# 🌐 IoT Veri İşleme Pipeline

Bu proje, IoT cihazlarından gelen verileri gerçek zamanlı olarak işleyen bir pipeline oluşturur.

## 🎯 Ne Yapacaksınız

IoT cihazlarından gelen sensör verilerini (sıcaklık, nem, basınç) AWS IoT Core üzerinden alıp, Lambda ile işleyerek DynamoDB'ye kaydeder ve CloudWatch ile izler.

## 🏗️ Mimari

```
IoT Cihazı → AWS IoT Core → Lambda → DynamoDB
                    ↓
              CloudWatch (Monitoring)
```

## 📋 Gereksinimler

- AWS CLI yapılandırılmış
- Python 3.8+
- MQTT test client (MQTT Explorer veya AWS IoT Test Client)

## 🚀 Kurulum

```bash
cd examples/iot-data-pipeline
./deploy.sh
```

## 📊 Test Etme

1. **IoT Test Client ile veri gönder:**
```bash
# Sıcaklık verisi
aws iot-data publish \
    --topic "sensors/temperature" \
    --payload '{"device_id": "sensor001", "temperature": 25.5, "humidity": 60, "timestamp": "2024-01-15T10:30:00Z"}'
```

2. **DynamoDB'de veriyi kontrol et:**
```bash
aws dynamodb scan --table-name YOUR-TABLE-NAME
```

3. **CloudWatch metriklerini izle:**
```bash
aws cloudwatch get-metric-statistics \
    --namespace "AWS/IoT" \
    --metric-name "MessagesPublished" \
    --dimensions Name=TopicName,Value=sensors/temperature \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum
```

## 🧹 Temizlik

```bash
./cleanup.sh
```

## 📚 Öğrenecekleriniz

- **AWS IoT Core**: MQTT mesajlaşma, Thing oluşturma, Topic yönetimi
- **Lambda**: Gerçek zamanlı veri işleme, JSON parsing
- **DynamoDB**: NoSQL veri saklama, TTL (Time To Live)
- **CloudWatch**: IoT metrikleri, alarm kurma
- **MQTT**: IoT protokolü, Topic yapısı

## 🎓 Deploy Sonrası Öğrenme Adımları

### ✅ Ne Öğrendiniz?
- **AWS IoT Core**: MQTT mesajlaşma ve device management
- **Lambda Real-time Processing**: Gerçek zamanlı veri işleme
- **DynamoDB NoSQL**: Hızlı veri saklama ve sorgulama
- **CloudWatch Monitoring**: IoT metrikleri ve alarmlar
- **Event-Driven Architecture**: Olay tabanlı sistem tasarımı

### 🔧 Şimdi Bunları Deneyebilirsiniz:

#### 1. Farklı Sensör Verileri Gönderin
```bash
# Sıcaklık sensörü verisi
aws iot-data publish \
    --topic "sensors/temperature" \
    --payload '{"device_id": "temp-sensor-001", "temperature": 25.5, "humidity": 60, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

# Nem sensörü verisi
aws iot-data publish \
    --topic "sensors/humidity" \
    --payload '{"device_id": "humidity-sensor-001", "humidity": 75, "pressure": 1013.25, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

# Basınç sensörü verisi
aws iot-data publish \
    --topic "sensors/pressure" \
    --payload '{"device_id": "pressure-sensor-001", "pressure": 1020.5, "altitude": 100, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
```

#### 2. DynamoDB'deki Verileri İnceleyin
```bash
# Tüm sensör verilerini listele
aws dynamodb scan --table-name YOUR-TABLE-NAME

# Belirli bir cihazın verilerini sorgula
aws dynamodb query \
    --table-name YOUR-TABLE-NAME \
    --key-condition-expression "device_id = :device" \
    --expression-attribute-values '{":device": {"S": "temp-sensor-001"}}'

# Son 1 saatteki verileri al
aws dynamodb scan \
    --table-name YOUR-TABLE-NAME \
    --filter-expression "processed_at > :time" \
    --expression-attribute-values '{":time": {"S": "'$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)'"}}'
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

#### 4. IoT Core Kaynaklarını Keşfedin
```bash
# IoT Thing'leri listele
aws iot list-things --query 'things[].thingName'

# IoT Policy'leri gör
aws iot list-policies --query 'policies[].policyName'

# IoT Rule'ları listele
aws iot list-topic-rules --query 'rules[].ruleName'

# IoT endpoint'ini al
aws iot describe-endpoint --endpoint-type iot:Data-ATS
```

#### 5. CloudWatch Metriklerini İzleyin
```bash
# IoT mesaj sayısını gör
aws cloudwatch get-metric-statistics \
    --namespace AWS/IoT \
    --metric-name MessagesPublished \
    --dimensions Name=TopicName,Value=sensors/temperature \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum

# IoT alarm durumunu kontrol et
aws cloudwatch describe-alarms \
    --alarm-names YOUR-ALARM-NAME
```

#### 6. Farklı Topic'ler Test Edin
```bash
# Hava durumu verisi
aws iot-data publish \
    --topic "weather/current" \
    --payload '{"location": "Istanbul", "temperature": 22, "condition": "sunny", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

# Enerji tüketimi verisi
aws iot-data publish \
    --topic "energy/consumption" \
    --payload '{"device_id": "smart-meter-001", "power": 2.5, "voltage": 220, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

# Trafik sensörü verisi
aws iot-data publish \
    --topic "traffic/sensors" \
    --payload '{"location": "highway-1", "vehicle_count": 45, "speed_avg": 65, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
```

#### 7. Veri Analizi Yapın
```bash
# DynamoDB'den veri çek ve analiz et
aws dynamodb scan \
    --table-name YOUR-TABLE-NAME \
    --query 'Items[?contains(topic.S, `temperature`)].temperature.N' \
    --output text | awk '{sum+=$1; count++} END {print "Ortalama sıcaklık:", sum/count}'

# En yüksek sıcaklığı bul
aws dynamodb scan \
    --table-name YOUR-TABLE-NAME \
    --query 'Items[?contains(topic.S, `temperature`)].temperature.N' \
    --output text | sort -n | tail -1
```

### 🚀 Sonraki Adımlar
1. **Veri Görselleştirme**: QuickSight ile dashboard oluşturun
2. **Machine Learning**: SageMaker ile anomali tespiti
3. **Veri Analizi**: Athena ile SQL sorguları
4. **Real-time Dashboard**: WebSocket ile canlı veri akışı
5. **Alerting System**: Sıcaklık/nem alarmları
6. **Data Lake**: S3 + Glue + Athena ile veri gölü

## 🔧 Özelleştirme

- Farklı sensör tipleri ekleyebilirsiniz
- Veri analizi için Athena kullanabilirsiniz
- Görselleştirme için QuickSight ekleyebilirsiniz
- Machine Learning için SageMaker entegre edebilirsiniz
