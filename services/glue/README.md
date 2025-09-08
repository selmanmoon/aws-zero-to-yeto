# AWS Glue

## 📖 Servis Hakkında

AWS Glue, tam yönetilen bir ETL (Extract, Transform, Load) servisidir. Verilerinizi farklı kaynaklardan alıp, işleyip, hedef sistemlere yüklemek için kullanılır.

### 🎯 Glue'nun Temel Özellikleri

- **Serverless ETL**: Sunucu yönetimi yok
- **Data Catalog**: Merkezi veri kataloğu
- **Crawlers**: Otomatik veri keşfi
- **Jobs**: ETL işleri
- **Development Endpoints**: Geliştirme ortamı
- **Data Quality**: Veri kalitesi kontrolü

### 🏗️ Glue Mimarisi

```
Data Sources (Veri Kaynakları)
    ↓
Glue Crawlers (Veri Keşfi)
    ↓
Data Catalog (Veri Kataloğu)
    ↓
Glue Jobs (ETL İşleri)
    ↓
Data Targets (Hedef Sistemler)
```

## 🔧 Glue Bileşenleri

### 1. Data Catalog
- **Metadata Store**: Veri hakkında bilgi saklar
- **Table Definitions**: Tablo şemaları
- **Partition Information**: Bölümleme bilgileri

### 2. Crawlers
- **Otomatik Keşif**: Veri kaynaklarını tarar
- **Schema Inference**: Şema çıkarımı yapar
- **Partition Detection**: Bölümleme tespit eder

### 3. ETL Jobs
- **PySpark**: Python tabanlı ETL
- **Scala**: Scala tabanlı ETL
- **Visual ETL**: Drag & drop arayüz

### 4. Development Endpoints
- **Interactive Development**: Etkileşimli geliştirme
- **Jupyter Notebooks**: Notebook desteği
- **Zeppelin**: Zeppelin notebook desteği

## 🚀 Deploy ve Test

### 1. Deploy
```bash
./deploy.sh
```

Bu komut şunları oluşturur:
- S3 bucket (input/output klasörleri ile)
- IAM Role (Glue service için)
- Glue Database
- 2 adet Glue Job (CSV to Parquet, JSON to Parquet)
- Sample data (CSV ve JSON)
- ETL scripts (PySpark)

### 2. Test Komutlarını Alma
Deploy sonrası çıktıda **tam komutlar** verilir. Örnek:

```bash
# CSV to Parquet Job'ı çalıştır:
aws glue start-job-run \
    --job-name csv-to-parquet-job-1756531231 \
    --arguments '{
        "--INPUT_PATH": "s3://aws-zero-to-yeto-glue-1756531231/input/csv/",
        "--OUTPUT_PATH": "s3://aws-zero-to-yeto-glue-1756531231/output/csv-parquet/"
    }' \
    --region eu-west-1
```

**⚠️ Önemli**: `[TIMESTAMP]` yerine gerçek sayılar kullanın! Deploy çıktısındaki komutları kopyalayın.

### 3. Job Durumunu Kontrol Etme
```bash
# Job çalışma durumunu kontrol et
aws glue get-job-runs --job-name csv-to-parquet-job-1756531231 --region eu-west-1

# S3 çıktılarını kontrol et
aws s3 ls s3://aws-zero-to-yeto-glue-1756531231/output/ --recursive --region eu-west-1
```

### 4. Cleanup
```bash
./cleanup.sh
```

Bu komut şunları temizler:
- Glue Job'ları
- Glue Database  
- IAM Role ve Policy'ler
- S3 Bucket ve tüm içeriği

### 📊 S3 Bucket Yapısı
```
s3://aws-zero-to-yeto-glue-[TIMESTAMP]/
├── input/
│   ├── csv/sample_data.csv
│   └── json/sample_data.json
├── output/
│   ├── csv-parquet/     (CSV job çıktısı)
│   └── json-parquet/    (JSON job çıktısı)
├── scripts/
│   ├── csv_to_parquet.py
│   └── json_to_parquet.py
└── sparkHistoryLogs/
```

### 🔍 Timestamp Sorunu Çözümü
Eğer `[TIMESTAMP]` hatası alırsanız:

1. **Deploy çıktısını kontrol edin** - Gerçek timestamp'ler verilir
2. **Manuel olarak bulun**:
   ```bash
   # S3 bucket'ları listele
   aws s3 ls | grep aws-zero-to-yeto-glue
   
   # Glue job'ları listele  
   aws glue get-jobs --region eu-west-1 | grep csv-to-parquet
   ```

## 💡 Kullanım Senaryoları

### 1. Veri Dönüşümü
- **CSV → Parquet**: Performans optimizasyonu
- **JSON → Avro**: Schema evolution
- **XML → JSON**: Format standardizasyonu

### 2. Veri Temizleme
- **Null Value Handling**: Eksik değer işleme
- **Data Validation**: Veri doğrulama
- **Duplicate Removal**: Tekrar eden kayıt temizleme

### 3. Veri Birleştirme
- **Multiple Sources**: Çoklu kaynak birleştirme
- **Data Enrichment**: Veri zenginleştirme
- **Aggregation**: Veri toplama

## 🔗 İlgili Servisler

Glue'yu öğrendikten sonra şu servisleri keşfedin:
- **Amazon Athena** - S3'teki verileri SQL ile sorgulama
- **Amazon Redshift** - Veri ambarı
- **Amazon EMR** - Büyük veri işleme
- **Amazon Kinesis** - Real-time veri işleme

## 📚 Kaynaklar

- [AWS Glue Documentation](https://docs.aws.amazon.com/glue/)
- [Glue Developer Guide](https://docs.aws.amazon.com/glue/latest/dg/)
- [Glue API Reference](https://docs.aws.amazon.com/glue/latest/dg/aws-glue-api.html)
- [Glue Pricing](https://aws.amazon.com/glue/pricing/)