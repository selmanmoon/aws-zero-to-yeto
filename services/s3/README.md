# Amazon S3 (Simple Storage Service)

## 📖 Servis Hakkında

Amazon S3, AWS'nin en temel ve en çok kullanılan depolama servisidir. Dosyalarınızı (nesneler) güvenli bir şekilde saklamanızı ve istediğiniz zaman erişmenizi sağlar.

### 🎯 S3'ün Temel Özellikleri

- **Yüksek Dayanıklılık**: %99.999999999 (11 dokuz) dayanıklılık
- **Yüksek Erişilebilirlik**: %99.99 erişilebilirlik
- **Sınırsız Depolama**: İstediğiniz kadar veri saklayabilirsiniz
- **Güvenlik**: Şifreleme, IAM entegrasyonu, bucket policies
- **Maliyet Etkin**: Sadece kullandığınız kadar ödersiniz

### 🏗️ S3 Mimarisi

```
Bucket (Kova)
├── Object 1 (Nesne 1)
├── Object 2 (Nesne 2)
├── Folder/ (Klasör)
│   ├── Object 3
│   └── Object 4
└── ...
```

## 📁 S3 Storage Classes (Depolama Sınıfları)

| Sınıf | Kullanım Amacı | Erişim Süresi | Maliyet |
|-------|----------------|---------------|---------|
| **S3 Standard** | Sık erişilen veriler | Anında | Orta |
| **S3 Intelligent-Tiering** | Erişim sıklığı bilinmeyen veriler | Anında | Düşük |
| **S3 Standard-IA** | Az erişilen veriler | 30 dakika | Düşük |
| **S3 One Zone-IA** | Az erişilen, tek bölge veriler | 30 dakika | Çok düşük |
| **S3 Glacier** | Arşiv verileri | 3-5 saat | En düşük |
| **S3 Glacier Deep Archive** | Uzun süreli arşiv | 12 saat | En düşük |

## 🔐 Güvenlik

### Bucket Policies
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::my-bucket/*"
        }
    ]
}
```

### CORS (Cross-Origin Resource Sharing)
```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "PUT", "POST"],
        "AllowedOrigins": ["https://example.com"],
        "ExposeHeaders": []
    }
]
```
▶️ Çalıştırma Adımları
cd services        # Servis dizinine geç
cd s3             # S3 dizinine geç

chmod +x deploy.sh cleanup.sh

./deploy.sh        # Deploy işlemi
./cleanup.sh       # Cleanup işlemi
 

## 💰 Maliyet Hesaplama

### Standart S3 Fiyatları (US East - N. Virginia)
- **Depolama**: $0.023/GB/ay
- **PUT/COPY/POST/LIST**: $0.0005/1000 istek
- **GET**: $0.0004/1000 istek
- **Veri Transferi**: $0.09/GB (outbound)

## 🚀 Pratik Örnekler

### 1. Web Sitesi Hosting
S3'ü statik web sitesi hosting için kullanabilirsiniz:
- HTML, CSS, JavaScript dosyaları
- Resimler ve medya dosyaları
- CloudFront ile CDN entegrasyonu

### 2. Backup ve Arşivleme
- Veritabanı yedekleri
- Log dosyaları
- Eski proje dosyaları

### 3. Data Lake
- Büyük veri analizi için veri depolama
- ETL işlemleri için veri kaynağı
- Machine Learning için veri setleri

### 4. Content Delivery
- Resim ve video dosyaları
- Uygulama dosyaları
- Dokümanlar

## 🔧 Best Practices

### 1. Bucket İsimlendirme
- Global olarak benzersiz olmalı
- Küçük harfler kullanın
- Tire (-) kullanabilirsiniz
- Alt çizgi (_) kullanmayın

### 2. Organizasyon
```
my-company-bucket/
├── images/
│   ├── products/
│   └── logos/
├── documents/
│   ├── invoices/
│   └── reports/
└── backups/
    ├── databases/
    └── applications/
```

### 3. Güvenlik
- Bucket'ları varsayılan olarak private yapın
- IAM kullanarak erişim kontrolü sağlayın
- Bucket versioning'i etkinleştirin
- Server-side encryption kullanın

### 4. Performans
- Büyük dosyalar için multipart upload kullanın
- CloudFront ile CDN kullanın
- Uygun storage class seçin

## 🧪 Test Senaryoları

Bu klasörde bulunan örnekler ile test edebileceğiniz senaryolar:

1. **Temel CRUD İşlemleri**
   - Dosya yükleme
   - Dosya indirme
   - Dosya silme
   - Dosya listeleme

2. **Web Sitesi Hosting**
   - Statik web sitesi deployment
   - CloudFront entegrasyonu

3. **Backup Sistemi**
   - Otomatik backup scripti
   - Lifecycle policies

4. **Data Pipeline**
   - Lambda ile dosya işleme
   - Event-driven mimari

## 📚 Öğrenme Kaynakları

### 📖 Resmi Dokümantasyon
- [AWS S3 Dokümantasyonu](https://docs.aws.amazon.com/s3/)
- [S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/best-practices.html)
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)

## 🎯 Sonraki Adımlar

S3'ü öğrendikten sonra şu servisleri keşfedin:
- **AWS Lambda** - S3 event'leri ile serverless işleme
- **Amazon CloudFront** - CDN ile performans optimizasyonu
- **AWS Glue** - ETL işlemleri
- **Amazon Athena** - S3'teki verileri SQL ile sorgulama
