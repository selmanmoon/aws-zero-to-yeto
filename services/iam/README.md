# AWS IAM (Identity and Access Management)

## 📖 Servis Hakkında

AWS IAM, AWS kaynaklarına güvenli erişimi yöneten servistir. Kullanıcılar, gruplar, roller ve izinleri yönetir. "Kim neye erişebilir?" sorusunun cevabını IAM verir.

### 🎯 IAM'ın Temel Özellikleri

- **Kullanıcı Yönetimi**: Bireysel AWS kullanıcıları
- **Grup Yönetimi**: Kullanıcı grupları ve toplu izin yönetimi
- **Rol Yönetimi**: Servisler arası güvenli erişim
- **Policy Yönetimi**: JSON tabanlı izin tanımları
- **MFA Desteği**: Multi-Factor Authentication

### 🏗️ IAM Hiyerarşisi

```
AWS Account (Root)
├── IAM Users (İnsanlar)
│   ├── Access Keys
│   ├── Passwords
│   └── MFA Devices
├── IAM Groups (Kullanıcı Grupları)
├── IAM Roles (Servisler/Uygulamalar)
└── IAM Policies (İzin Kuralları)
```

## 💰 Maliyet

**IAM tamamen ücretsizdir!** ✅
- Kullanıcı sayısı limiti yok
- Policy sayısı limiti yok
- Rol sayısı limiti yok

## 🔐 Temel Kavramlar

### 1. IAM Users (Kullanıcılar)
```python
# IAM kullanıcısı oluşturma
user_response = iam_client.create_user(
    UserName='ahmet-developer',
    Path='/developers/',
    Tags=[
        {'Key': 'Department', 'Value': 'Engineering'},
        {'Key': 'Project', 'Value': 'AWS-Zero-to-Yeto'}
    ]
)
```

### 2. IAM Groups (Gruplar)
```python
# Grup oluşturma
group_response = iam_client.create_group(
    GroupName='Developers',
    Path='/teams/'
)

# Kullanıcıyı gruba ekleme
iam_client.add_user_to_group(
    GroupName='Developers',
    UserName='ahmet-developer'
)
```

### 3. IAM Roles (Roller)
```python
# EC2 için role oluşturma
assume_role_policy = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }
    ]
}

role_response = iam_client.create_role(
    RoleName='EC2-S3-Access-Role',
    AssumeRolePolicyDocument=json.dumps(assume_role_policy)
)
```

### 4. IAM Policies (İzinler)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::my-bucket/*"
        },
        {
            "Effect": "Deny",
            "Action": "s3:DeleteObject",
            "Resource": "*"
        }
    ]
}
```

## 🚀 IAM Best Practices

### 1. Root Kullanıcı Güvenliği
```bash
# ❌ Yapmayın
# Root kullanıcı ile günlük işler

# ✅ Yapın
# IAM kullanıcıları oluşturun
aws iam create-user --user-name admin-user
aws iam attach-user-policy --user-name admin-user --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### 2. Least Privilege Principle
```python
# ❌ Geniş izinler
"Action": "*"

# ✅ Spesifik izinler
"Action": [
    "s3:GetObject",
    "s3:PutObject"
]
```

### 3. MFA Aktivasyonu
```python
# MFA device eklemek
iam_client.enable_mfa_device(
    UserName='ahmet-developer',
    SerialNumber='arn:aws:iam::123456789012:mfa/ahmet-developer',
    AuthenticationCode1='123456',
    AuthenticationCode2='654321'
)
```

### 4. Access Key Rotation
```python
# Yeni access key oluştur
new_key = iam_client.create_access_key(UserName='ahmet-developer')

# Eski key'i sil (test ettikten sonra)
iam_client.delete_access_key(
    UserName='ahmet-developer',
    AccessKeyId='AKIAIOSFODNN7EXAMPLE'
)
```

## 🛡️ Güvenlik Senaryoları

### 1. Developer Erişimi
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "s3:GetObject",
                "s3:PutObject",
                "lambda:InvokeFunction"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:RequestedRegion": "eu-west-1"
                }
            }
        }
    ]
}
```

### 2. Lambda Execution Role
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::my-lambda-bucket/*"
        }
    ]
}
```

### 3. Cross-Account Access
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::ACCOUNT-B:user/external-user"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

## 📊 IAM Monitoring

### 1. CloudTrail ile Audit
```python
# IAM API calls monitoring
cloudtrail_events = cloudtrail_client.lookup_events(
    LookupAttributes=[
        {
            'AttributeKey': 'EventSource',
            'AttributeValue': 'iam.amazonaws.com'
        }
    ]
)
```

### 2. Access Analyzer
```python
# Access Analyzer findings
access_analyzer = boto3.client('accessanalyzer')

findings = access_analyzer.list_findings(
    analyzerArn='arn:aws:access-analyzer:region:account:analyzer/analyzer-name'
)
```

### 3. Credential Report
```python
# Kullanıcı credential raporu
iam_client.generate_credential_report()
time.sleep(10)  # Rapor hazırlanmasını bekle

report = iam_client.get_credential_report()
credential_data = report['Content'].decode('utf-8')
```

## 🧪 Test Senaryoları

Bu klasörde bulunan örnekler ile test edebileceğiniz senaryolar:

1. **Temel Kullanıcı Yönetimi**
   - IAM kullanıcı oluşturma/silme
   - Group membership yönetimi
   - Password policy uygulama

2. **Role-Based Access**
   - EC2 instance profile oluşturma
   - Lambda execution role
   - Cross-service access

3. **Policy Testing**
   - Policy simulator kullanımı
   - Least privilege testing
   - Condition-based access

4. **Security Audit**
   - Unused credentials detection
   - Over-privileged users
   - MFA compliance check

5. **Automation**
   - User lifecycle management
   - Automatic role creation
   - Policy template system

## 🔍 Troubleshooting

### Yaygın Hatalar

#### 1. Access Denied
```python
# Problem: Yetersiz izin
# Çözüm: Policy kontrolü
try:
    response = s3_client.list_buckets()
except ClientError as e:
    if e.response['Error']['Code'] == 'AccessDenied':
        print("S3 ListBuckets izni gerekli")
```

#### 2. Role Assumption Failure
```python
# Problem: Trust relationship hatası
# Çözüm: AssumeRolePolicyDocument kontrolü
trust_policy = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"Service": "lambda.amazonaws.com"},  # Doğru servis
            "Action": "sts:AssumeRole"
        }
    ]
}
```

#### 3. Policy Size Limit
```python
# Problem: Policy çok büyük (>6144 karakter)
# Çözüm: Managed policies kullan veya böl
```

## 📚 Öğrenme Kaynakları

- [AWS IAM Dokümantasyonu](https://docs.aws.amazon.com/iam/)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [IAM Policy Simulator](https://policysim.aws.amazon.com/)
- **Selman Ay YouTube**: IAM ve Güvenlik videoları

## 🎯 Sonraki Adımlar

IAM'ı öğrendikten sonra şu konuları keşfedin:
- **AWS CloudTrail** - API audit logging
- **AWS Config** - Compliance monitoring  
- **AWS Organizations** - Multi-account management
- **AWS SSO** - Centralized access management
