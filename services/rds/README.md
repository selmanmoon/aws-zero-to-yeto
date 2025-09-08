# Amazon RDS (Relational Database Service)

## 📖 Servis Hakkında

Amazon RDS, AWS'nin tam yönetilen ilişkisel veritabanı servisidir. MySQL, PostgreSQL, MariaDB, Oracle, SQL Server ve Amazon Aurora destekler.

### 🎯 RDS'nin Temel Özellikleri

- **Tam Yönetilen**: Kurulum, patch, backup otomatik
- **Multi-AZ Deployment**: Yüksek erişilebilirlik
- **Read Replicas**: Okuma performansı artırma
- **Automated Backups**: Otomatik yedekleme
- **Monitoring**: CloudWatch entegrasyonu

## 💰 Free Tier Limitleri
- **750 saat** db.t3.micro instance (12 ay)
- **20GB** SSD depolama
- **20GB** backup depolama

## 🗄️ Desteklenen Veritabanları

### MySQL
```python
# MySQL bağlantısı
import pymysql

connection = pymysql.connect(
    host='mydb.abcdef.us-east-1.rds.amazonaws.com',
    user='admin',
    password='password',
    database='myapp',
    port=3306
)

cursor = connection.cursor()
cursor.execute("SELECT VERSION()")
version = cursor.fetchone()
print(f"MySQL Version: {version[0]}")
```

### PostgreSQL
```python
# PostgreSQL bağlantısı
import psycopg2

connection = psycopg2.connect(
    host='mydb.abcdef.us-east-1.rds.amazonaws.com',
    database='myapp',
    user='admin',
    password='password',
    port=5432
)

cursor = connection.cursor()
cursor.execute("SELECT version();")
version = cursor.fetchone()
print(f"PostgreSQL Version: {version[0]}")
```

## 🔧 RDS Instance Oluşturma

```python
import boto3

rds = boto3.client('rds', region_name='eu-west-1')

response = rds.create_db_instance(
    DBInstanceIdentifier='aws-zero-to-yeto-db',
    DBInstanceClass='db.t3.micro',  # Free Tier
    Engine='mysql',
    EngineVersion='8.0.35',
    MasterUsername='admin',
    MasterUserPassword='SecurePassword123!',
    AllocatedStorage=20,  # GB
    VpcSecurityGroupIds=['sg-12345'],
    DBSubnetGroupName='my-subnet-group',
    BackupRetentionPeriod=7,
    MultiAZ=False,  # Free Tier'da Multi-AZ yok
    PubliclyAccessible=True,  # Sadece test için
    StorageType='gp2',
    StorageEncrypted=True
)
```

## 🔐 Güvenlik Best Practices

```python
security_practices = {
    'network': 'VPC içinde private subnet kullanın',
    'access': 'Security groups ile port erişimi kısıtlayın',
    'auth': 'Güçlü master password kullanın',
    'encryption': 'Encryption at rest ve in transit aktif edin',
    'monitoring': 'CloudWatch logs ve monitoring kurun'
}
```

## 🧪 Test Senaryoları

1. **Web Uygulaması Backend**
2. **Data Analytics Pipeline**
3. **Multi-Region Deployment**
4. **Backup & Recovery Testing**
5. **Performance Optimization**

## 📚 Öğrenme Kaynakları

- [RDS Dokümantasyonu](https://docs.aws.amazon.com/rds/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
