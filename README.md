# AWS Zero to Yeto (Yettiği Kadar AWS Öğren)

AWS'yi sıfırdan öğrenmek için hazırlanmış, veri ve yapay zeka odaklı açık kaynak Türkçe rehber.

---

## Veri & AI Servisleri

| Servis | Açıklama |
|--------|----------|
| Amazon S3 | Dosyalarınızı bulutta saklayın. Bucket oluşturun, upload/download yapın. |
| Amazon RDS | MySQL, PostgreSQL, Aurora ile yönetilen veritabanı. Backup ve scaling otomatik. |
| Amazon DynamoDB | Milisaniye response time'lı NoSQL. Key-value veya document store olarak kullanabilirsiniz. |
| Amazon SageMaker | ML model eğitimi ve deployment. Jupyter notebook dahil. |
| Amazon Bedrock | Claude, Nova, Llama gibi foundation model'leri API ile çağırın. |
| AWS Glue | CSV'den Parquet'e dönüşüm, veri kataloglama, ETL. |

## Temel Servisler

| Servis | Açıklama |
|--------|----------|
| AWS Lambda | Sunucu düşünmeden kod çalıştırın. Event-driven, sadece çalıştığı süre için ödeme. |
| AWS IAM | Kim neye erişebilir? Kullanıcılar, roller, policy'ler. |
| Amazon CloudWatch | Log toplama, metrik izleme, alarm kurma. |

---

## Repository Yapısı

```
aws-zero-to-yeto/
├── services/
│   ├── s3/
│   ├── rds/
│   ├── dynamodb/
│   ├── sagemaker/
│   ├── bedrock/
│   ├── glue/
│   ├── lambda/
│   ├── iam/
│   └── cloudwatch/
├── examples/
│   ├── bedrock-s3-chat/
│   ├── iot-data-pipeline/
│   └── s3-lambda-api/
└── getting-started/
```

---

## Örnek Projeler

| Proje | Servisler |
|-------|-----------|
| Akıllı Belge İşleme | S3 + Textract + Lambda + DynamoDB |
| Veri Pipeline & AI Analiz | Glue + Bedrock + S3 |
| Serverless Web App | Lambda + API Gateway + S3 + RDS |
| IoT Veri Pipeline | IoT Core + Lambda + DynamoDB + CloudWatch |

---

[Selman Ay YouTube](https://www.youtube.com/@selmanay) · [AWS Türkiye Blog](https://aws.amazon.com/tr/blogs/)

MIT License
