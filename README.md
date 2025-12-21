# AWS ZERO to YETO (YETTİĞİ KADAR AWS ÖĞREN) 🚀

Merhaba! Bu repository'de AWS'yi sıfırdan öğreneceksiniz. Özellikle **veri ve yapay zeka** odaklı servislere ve temel AWS servislerine odaklanıyoruz. **Türkiye'nin en iyi açık kaynak AWS öğrenme kaynağı** olmayı hedefliyoruz ve hep beraber geliştirebiliriz! 🇹🇷

## 🎯 Hedef

Bu repository ile:
- AWS'nin temel servislerini pratik örneklerle öğreneceksiniz
- Her servis için gerçek dünya senaryoları göreceksiniz
- Otomatik deployment scriptleri ile hızlıca test edebileceksiniz
- Türkçe dokümantasyon ile kolayca takip edebileceksiniz

## 📚 Kapsanan AWS Servisleri

### 🔥 Veri & AI Servisleri
- **Amazon S3** - Dosya depolama ve yönetimi
- **Amazon RDS** - İlişkisel veritabanı servisi
- **Amazon DynamoDB** - NoSQL veritabanı
- **Amazon SageMaker** - Makine öğrenmesi
- **Amazon Bedrock** - Generative AI ve Foundation Models
- **AWS Glue** - ETL ve veri kataloğu

### 🛠️ Temel AWS Servisleri
- **AWS Lambda** - Serverless fonksiyonlar
- **AWS IAM** - Kimlik ve erişim yönetimi
- **Amazon CloudWatch** - Monitoring ve loglama

### 📦 Container Orchestration & Kubernetes
- **Amazon EKS** – Kubernetes servisi

## 📁 Repository Yapısı

```
aws-zero-to-yeto/
├── examples/                    # Pratik AWS proje örnekleri
│   ├── bedrock-s3-chat/         # Bedrock + S3 entegrasyonu
│   ├── iot-data-pipeline/       # IoT veri işleme pipeline'ı
│   └── s3-lambda-api/           # S3 + Lambda + API Gateway
├── services/                    # Her AWS servisi için ayrı klasör
│   ├── s3/                      # Amazon S3 örnekleri
│   ├── lambda/                  # AWS Lambda örnekleri
│   ├── rds/                     # Amazon RDS örnekleri
│   ├── dynamodb/                # Amazon DynamoDB örnekleri
│   ├── bedrock/                 # Amazon Bedrock örnekleri
│   ├── sagemaker/               # Amazon SageMaker örnekleri
│   ├── glue/                    # AWS Glue örnekleri
│   ├── iam/                     # AWS IAM örnekleri
│   ├── cloudwatch/              # Amazon CloudWatch örnekleri
│   └── eks/                     # Amazon EKS (Kubernetes) örnekleri

├── getting-started/             # Başlangıç rehberi
└── cleanup.sh                   # Genel temizlik scripti
```

## 🚀 Hızlı Başlangıç

Başlamak için önce **[Başlangıç Rehberi](getting-started/getting-started.md)**'ni okuyun. Orada detaylı kurulum adımları ve öğrenme yolunu bulacaksınız.

**Hızlı başlangıç için:**

1. **AWS CLI Kurulumu**
   ```bash
   # macOS için
   brew install awscli
   
   # AWS kimlik bilgilerini yapılandırın
   aws configure
   ```

2. **Repository'yi klonlayın**
   ```bash
   git clone https://github.com/your-username/aws-zero-to-yeto.git
   cd aws-zero-to-yeto
   ```

3. **İlk servisi deneyin**
   ```bash
   cd services/s3
   ./deploy.sh
   ```

4. **Temizlik yapın (ÖNEMLİ!)**
   ```bash
   # Her servis için ayrı cleanup script'i
   cd services/s3
   ./cleanup.sh
   ```

**Detaylı rehber için:** [getting-started/getting-started.md](getting-started/getting-started.md)

## 📖 Öğrenme Yolu

### Seviye 1: Temeller
1. **S3** - Dosya depolama temelleri
2. **IAM** - Güvenlik ve erişim kontrolü
3. **CloudWatch** - Monitoring ve loglama

### Seviye 2: Veri Servisleri
1. **RDS** - İlişkisel veritabanları
2. **DynamoDB** - NoSQL veritabanları
3. **Glue** - ETL ve veri kataloğu

### Seviye 3: AI/ML Servisleri
1. **SageMaker** - Makine öğrenmesi
2. **Bedrock** - Generative AI

### Seviye 4: Serverless & Otomasyon
1. **Lambda** - Serverless fonksiyonlar

## 💡 Her Servis İçin Neler Var?

Her AWS servisi klasöründe şunları bulacaksınız:

- 📖 **README.md** - Servis hakkında detaylı Türkçe açıklama
- 🚀 **deploy.sh** - Otomatik deployment scripti
- 🧹 **cleanup.sh** - Kaynakları temizleme scripti
- 📝 **examples/** - Pratik örnekler ve Python kodları

## 🎯 Gerçek Dünya Projeleri

Bu repository'de öğrendiklerinizi kullanarak yapabileceğiniz projeler:

1. **Akıllı Belge İşleme Sistemi**
   - S3 + Textract + Lambda + DynamoDB

2. **Veri Pipeline ve AI Analiz Platformu**
   - Glue + Bedrock + S3

3. **Serverless Web Uygulaması**
   - Lambda + API Gateway + S3 + RDS

4. **IoT Veri İşleme Pipeline**
   - IoT Core + Lambda + DynamoDB + CloudWatch

## 💰 Maliyet ve Free Tier

### 🆓 AWS Free Tier (12 Ay Ücretsiz)
Bu repository'deki tüm örnekler **AWS Free Tier** limitleri içinde çalışacak şekilde tasarlanmıştır:

- **S3**: 5GB depolama, 20,000 GET, 2,000 PUT istekleri
- **Lambda**: 1M istek, 400,000 GB-saniye
- **Bedrock**: Claude 3 Sonnet - 5M input, 5M output token
- **Glue**: 1M Data Catalog object, 10 DPU-saat
- **RDS**: 750 saat/ay (db.t3.micro)
- **DynamoDB**: 25GB depolama, 25 WCU, 25 RCU
- **CloudWatch**: 5GB log ingestion, 1M API istekleri

### ⚠️ Maliyet Uyarıları
- Free Tier limitlerini aştığınızda ücretlendirilirsiniz
- Kullanmadığınız kaynakları mutlaka silin
- `./cleanup.sh` script'ini kullanarak temizlik yapın
- AWS Billing Dashboard'dan maliyetleri takip edin

## 🔧 Gereksinimler

- AWS Hesabı (Free Tier önerilir)
- AWS CLI
- Python 3.8+
- Docker (bazı örnekler için)
- Git

## 📝 Katkıda Bulunma

Bu repository'ye katkıda bulunmak istiyorsanız:

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/yeni-servis`)
3. Değişikliklerinizi commit edin (`git commit -am 'Yeni servis eklendi'`)
4. Branch'inizi push edin (`git push origin feature/yeni-servis`)
5. Pull Request oluşturun

## 📞 Destek ve Topluluk

- [Selman Ay YouTube Kanalı](https://www.youtube.com/@selmanay)
- Pratik örnekler ve gerçek dünya senaryoları

### 📚 Öğrenme Kaynakları
- [AWS Türkiye Blog](https://aws.amazon.com/tr/blogs/)
- [AWS Türkiye YouTube](https://www.youtube.com/@awsturkiye)
- [AWS Türkiye LinkedIn](https://www.linkedin.com/company/aws-turkiye/)

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakınız.

---

**AWS ZERO to YETO** - Yettiği kadar AWS öğren! 🚀

*Bu repository sürekli güncellenmektedir. Yeni AWS servisleri ve örnekler eklenmeye devam edecektir.*
