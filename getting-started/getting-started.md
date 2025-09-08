# 🚀 AWS ZERO to YETO - Başlangıç Rehberi

Bu rehber, AWS ZERO to YETO repository'sini kullanarak AWS servislerini öğrenmeye başlamanız için hazırlanmıştır.

## 📋 İçindekiler

1. [Gereksinimler](#gereksinimler)
2. [Kurulum](#kurulum)
3. [İlk Adımlar](#ilk-adımlar)
4. [Servisler](#servisler)
5. [Projeler](#projeler)
6. [Test Etme](#test-etme)
7. [Temizlik](#temizlik)

## 🔧 Gereksinimler

### Temel Gereksinimler
- **AWS CLI**: AWS komut satırı aracı
- **Bash**: Terminal/shell erişimi
- **AWS Hesabı**: Aktif AWS hesabı
- **İnternet Bağlantısı**: AWS servislerine erişim

### AWS CLI Kurulumu
```bash
# macOS
brew install awscli

# Linux
sudo apt-get install awscli

# Windows
# https://aws.amazon.com/cli/ adresinden indirin
```

### AWS CLI Yapılandırması
```bash
aws configure
# AWS Access Key ID: [ENTER]
# AWS Secret Access Key: [ENTER]
# Default region name: eu-west-1
# Default output format: json
```

## 🚀 Kurulum

### 1. Repository'yi İndirin
```bash
git clone https://github.com/your-username/zero-to-yeto.git
cd zero-to-yeto
```

### 2. Ortam Kontrolü
```bash
# Getting started script'ini çalıştırın
./getting-started/getting-started.sh
```

Bu script:
- AWS CLI kurulumunu kontrol eder
- AWS kimlik bilgilerini doğrular
- Gerekli izinleri kontrol eder
- Eksik servisleri raporlar

## 🎯 İlk Adımlar

### 1. Basit Bir Servis Deneyin
```bash
# S3 servisini deploy edin
cd services/s3
./deploy.sh

# Test edin
aws s3 ls

# Temizleyin
./cleanup.sh
```

### 2. İlk Projeyi Çalıştırın
```bash
# S3 + Lambda + API projesini deneyin
cd examples/s3-lambda-api
./deploy.sh

# Test edin (deploy çıktısındaki komutları kullanın)
# Temizleyin
./cleanup.sh
```

## 🛠️ Servisler

### Temel Servisler
- **S3**: Dosya depolama
- **Lambda**: Serverless fonksiyonlar
- **DynamoDB**: NoSQL veritabanı
- **CloudWatch**: Monitoring ve loglama

### Gelişmiş Servisler
- **Bedrock**: Generative AI
- **Glue**: ETL işlemleri
- **SageMaker**: Machine Learning
- **RDS**: İlişkisel veritabanı

### Servis Deploy Etme
```bash
cd services/SERVICE_NAME
./deploy.sh    # Deploy et
./cleanup.sh   # Temizle
```

## 🎨 Projeler

### Mevcut Projeler
1. **S3-Lambda-API**: Serverless dosya işleme
2. **Bedrock-S3-Chat**: AI chatbot
3. **IoT-Data-Pipeline**: IoT veri işleme

### Proje Çalıştırma
```bash
cd examples/PROJECT_NAME
./deploy.sh    # Deploy et
# Test komutlarını çalıştır
./cleanup.sh   # Temizle
```

## 🧪 Test Etme

### Deploy Sonrası Test
Her deploy script'i çalıştıktan sonra:
1. **Çıktıyı okuyun**: Deploy script'i test komutları verir
2. **Test komutlarını çalıştırın**: Verilen örnekleri deneyin
3. **Sonuçları kontrol edin**: AWS Console'da kaynakları görün
4. **Logları inceleyin**: CloudWatch Logs'da detayları görün

### Örnek Test Komutları
```bash
# S3 test
aws s3 ls s3://YOUR-BUCKET-NAME

# Lambda test
aws lambda list-functions

# DynamoDB test
aws dynamodb list-tables

# API test
curl https://YOUR-API-GATEWAY-URL/endpoint
```

## 🧹 Temizlik

### Önemli: Her Zaman Temizleyin!
```bash
# Proje temizliği
cd examples/PROJECT_NAME
./cleanup.sh

# Servis temizliği
cd services/SERVICE_NAME
./cleanup.sh

# Tüm kaynakları temizle (dikkatli kullanın!)
./cleanup.sh
```

### Temizlik Kontrolü
```bash
# Kalan kaynakları kontrol edin
aws s3 ls
aws lambda list-functions
aws dynamodb list-tables
aws iam list-roles --query 'Roles[?contains(RoleName, `aws-zero-to-yeto`)]'
```

## 📚 Öğrenme Yol Haritası

### Başlangıç (1-2 hafta)
1. **S3**: Dosya depolama temelleri
2. **Lambda**: Serverless fonksiyonlar
3. **API Gateway**: REST API oluşturma

### Orta Seviye (2-4 hafta)
4. **DynamoDB**: NoSQL veritabanı
5. **CloudWatch**: Monitoring ve loglama
6. **IAM**: Güvenlik ve izinler

### İleri Seviye (1-2 ay)
7. **Bedrock**: Generative AI
8. **Glue**: ETL işlemleri
9. **SageMaker**: Machine Learning

## 🆘 Sorun Giderme

### Yaygın Sorunlar

#### 1. AWS CLI Hatası
```bash
# Kimlik bilgilerini kontrol edin
aws sts get-caller-identity

# Region'ı kontrol edin
aws configure get region
```

#### 2. İzin Hatası
```bash
# Gerekli izinleri kontrol edin
aws iam get-user
aws iam list-attached-user-policies --user-name YOUR_USERNAME
```

#### 3. Resource Conflict
```bash
# Kalan kaynakları temizleyin
./cleanup.sh

# Manuel temizlik
aws s3 rb s3://BUCKET-NAME --force
aws lambda delete-function --function-name FUNCTION-NAME
```

#### 4. Region Uyumsuzluğu
```bash
# Tüm servislerin aynı region'da olduğundan emin olun
aws configure set region eu-west-1
```

### Log Kontrolü
```bash
# Lambda logları
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda"

# CloudWatch metrikleri
aws cloudwatch list-metrics --namespace AWS/Lambda
```

## 🎓 Sonraki Adımlar

### 1. AWS Console'u Keşfedin
- Deploy ettiğiniz kaynakları AWS Console'da görün
- Metrikleri ve logları inceleyin
- Farklı servisleri keşfedin

### 2. Dokümantasyonu Okuyun
- Her servisin README'sini okuyun
- AWS resmi dokümantasyonunu inceleyin
- Örnek komutları deneyin

### 3. Projeleri Geliştirin
- Mevcut projeleri özelleştirin
- Yeni özellikler ekleyin
- Farklı servisleri birleştirin

### 4. Toplulukla Bağlantı Kurun
- GitHub'da issue açın
- Pull request gönderin
- Deneyimlerinizi paylaşın

## 📞 Destek

### Yardım Alma
1. **README dosyalarını okuyun**: Her servis/proje için detaylı açıklamalar
2. **GitHub Issues**: Sorunlarınızı bildirin
3. **AWS Dokümantasyonu**: Resmi AWS rehberleri
4. **Topluluk**: Stack Overflow, Reddit AWS toplulukları

### Katkıda Bulunma
1. **Bug Report**: Hataları bildirin
2. **Feature Request**: Yeni özellikler önerin
3. **Pull Request**: Kod katkısı yapın
4. **Dokümantasyon**: Rehberleri geliştirin

---

**🎉 Başarılar! AWS öğrenme yolculuğunuzda başarılar dileriz!**

> **Not**: Bu rehber sürekli güncellenmektedir. En güncel bilgiler için GitHub repository'sini takip edin.