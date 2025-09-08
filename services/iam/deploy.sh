#!/bin/bash

# AWS ZERO to YETO - IAM Demo Setup
# Bu script IAM yönetimi örneklerini gösterir

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

PROJECT_NAME="aws-zero-to-yeto-iam-$(date +%s)"

print_info "🔐 IAM Demo Setup başlatılıyor..."
print_warning "⚠️  Bu script demo amaçlıdır. Production'da dikkatli kullanın!"

# 1. Demo IAM User oluştur
print_info "👤 Demo IAM kullanıcısı oluşturuluyor..."

USER_NAME="${PROJECT_NAME}-demo-user"
GROUP_NAME="${PROJECT_NAME}-demo-group"
ROLE_NAME="${PROJECT_NAME}-demo-role"

# Kullanıcı oluştur
aws iam create-user \
    --user-name $USER_NAME \
    --path "/demo/" \
    --tags Key=Project,Value=aws-zero-to-yeto Key=Type,Value=demo

print_success "Demo kullanıcı oluşturuldu: $USER_NAME"

# 2. Demo Group oluştur
print_info "👥 Demo IAM grubu oluşturuluyor..."

aws iam create-group \
    --group-name $GROUP_NAME \
    --path "/demo/"

# Kullanıcıyı gruba ekle
aws iam add-user-to-group \
    --group-name $GROUP_NAME \
    --user-name $USER_NAME

print_success "Demo grup oluşturuldu ve kullanıcı eklendi: $GROUP_NAME"

# 3. Demo Policy oluştur
print_info "📋 Demo IAM policy oluşturuluyor..."

POLICY_NAME="${PROJECT_NAME}-demo-policy"

cat > demo-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::aws-zero-to-yeto-*",
                "arn:aws:s3:::aws-zero-to-yeto-*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeImages"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Deny",
            "Action": [
                "ec2:TerminateInstances",
                "ec2:StopInstances"
            ],
            "Resource": "*"
        }
    ]
}
EOF

POLICY_ARN=$(aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://demo-policy.json \
    --description "AWS ZERO to YETO Demo Policy" \
    --query 'Policy.Arn' --output text)

print_success "Demo policy oluşturuldu: $POLICY_ARN"

# 4. Policy'yi gruba attach et
aws iam attach-group-policy \
    --group-name $GROUP_NAME \
    --policy-arn $POLICY_ARN

print_success "Policy gruba bağlandı"

# 5. Demo Role oluştur (Lambda için)
print_info "🎭 Demo IAM role oluşturuluyor..."

cat > trust-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

ROLE_ARN=$(aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --description "AWS ZERO to YETO Demo Role for Lambda" \
    --tags Key=Project,Value=aws-zero-to-yeto Key=Type,Value=demo \
    --query 'Role.Arn' --output text)

# Lambda basic execution policy ekle
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

print_success "Demo role oluşturuldu: $ROLE_ARN"

# 6. Demo için access key oluştur (güvenlik uyarısı ile)
print_warning "🔑 Demo access key oluşturuluyor..."
print_warning "⚠️  Production'da access key kullanımını minimumda tutun!"

ACCESS_KEY_INFO=$(aws iam create-access-key \
    --user-name $USER_NAME \
    --query 'AccessKey.[AccessKeyId,SecretAccessKey]' \
    --output text)

ACCESS_KEY_ID=$(echo $ACCESS_KEY_INFO | cut -d' ' -f1)
SECRET_ACCESS_KEY=$(echo $ACCESS_KEY_INFO | cut -d' ' -f2)

print_success "Demo access key oluşturuldu"

# 7. Deployment bilgilerini kaydet

# Temizlik
rm -f demo-policy.json trust-policy.json

print_success "🎉 IAM Demo Setup tamamlandı!"
print_info "👤 Demo User: $USER_NAME"
print_info "👥 Demo Group: $GROUP_NAME"
print_info "🎭 Demo Role: $ROLE_NAME"
print_info "📝 Deployment bilgileri README'de mevcut"
print_warning "⚠️  Access key'leri güvenli tutun ve test sonrası silin!"

echo ""
print_info "📚 Python örneğini çalıştırmak için:"
echo "  cd examples/python"
echo "  python3 iam_manager.py"
