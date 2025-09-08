#!/bin/bash

# AWS ZERO to YETO - RDS Cleanup Script
# Bu script deploy.sh ile yaratılan RDS kaynaklarını siler

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Konfigürasyon
PROJECT_NAME="aws-zero-to-yeto"
REGION="eu-west-1"

print_info "🧹 AWS ZERO to YETO - RDS Cleanup"
print_info "📍 Region: $REGION"

# En son deploy edilen RDS kaynaklarını bul (timestamp'a göre en yüksek)
print_info "🔍 En son deploy edilen RDS kaynakları aranıyor..."

# En yüksek timestamp'li RDS kaynaklarını bul
LATEST_TIMESTAMP=$(aws rds describe-db-instances --region $REGION --query 'DBInstances[?contains(DBInstanceIdentifier, `aws-zero-to-yeto-rds-mysql`)].DBInstanceIdentifier' --output text 2>/dev/null | sed 's/aws-zero-to-yeto-rds-mysql-\([0-9]*\)/\1/' | sort -n | tail -1)

if [ -z "$LATEST_TIMESTAMP" ]; then
    print_warning "RDS kaynakları bulunamadı"
    exit 0
fi

DB_INSTANCE_IDENTIFIER="${PROJECT_NAME}-rds-mysql-${LATEST_TIMESTAMP}"
DB_SUBNET_GROUP_NAME="${PROJECT_NAME}-rds-subnet-group-${LATEST_TIMESTAMP}"
SECURITY_GROUP_NAME="${PROJECT_NAME}-rds-sg-${LATEST_TIMESTAMP}"
VPC_NAME="${PROJECT_NAME}-rds-vpc-${LATEST_TIMESTAMP}"

print_info "🎯 Hedef kaynaklar:"
print_info "   - RDS Instance: $DB_INSTANCE_IDENTIFIER"
print_info "   - DB Subnet Group: $DB_SUBNET_GROUP_NAME"
print_info "   - Security Group: $SECURITY_GROUP_NAME"
print_info "   - VPC: $VPC_NAME"

echo ""
print_warning "⚠️  Bu kaynaklar silinecek!"
read -p "Devam etmek istiyor musunuz? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_info "İşlem iptal edildi"
    exit 0
fi

echo ""
print_info "🗑️  Kaynaklar siliniyor..."

# 1. RDS Instance'ı sil
print_info "📊 RDS Instance siliniyor: $DB_INSTANCE_IDENTIFIER"
if aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --region $REGION >/dev/null 2>&1; then
    aws rds delete-db-instance --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --skip-final-snapshot --region $REGION
    print_info "   RDS Instance silinme işlemi başlatıldı (5-10 dakika sürebilir)"
    
    # RDS Instance'ın silinmesini bekle
    print_info "   RDS Instance'ın silinmesi bekleniyor..."
    aws rds wait db-instance-deleted --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --region $REGION
    print_success "✅ RDS Instance silindi: $DB_INSTANCE_IDENTIFIER"
else
    print_warning "⚠️ RDS Instance bulunamadı: $DB_INSTANCE_IDENTIFIER"
fi

# 2. DB Subnet Group'u sil
print_info "🌐 DB Subnet Group siliniyor: $DB_SUBNET_GROUP_NAME"
if aws rds describe-db-subnet-groups --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" --region $REGION >/dev/null 2>&1; then
    aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" --region $REGION
    print_success "✅ DB Subnet Group silindi: $DB_SUBNET_GROUP_NAME"
else
    print_warning "⚠️ DB Subnet Group bulunamadı: $DB_SUBNET_GROUP_NAME"
fi

# 3. Security Group'u bul ve sil
print_info "🔒 Security Group siliniyor: $SECURITY_GROUP_NAME"
SG_ID=$(aws ec2 describe-security-groups --region $REGION --query "SecurityGroups[?contains(GroupName, '$SECURITY_GROUP_NAME')].GroupId" --output text)
if [ ! -z "$SG_ID" ]; then
    aws ec2 delete-security-group --group-id "$SG_ID" --region $REGION
    print_success "✅ Security Group silindi: $SECURITY_GROUP_NAME ($SG_ID)"
else
    print_warning "⚠️ Security Group bulunamadı: $SECURITY_GROUP_NAME"
fi

# 4. Subnet'leri bul ve sil
print_info "🌐 Subnet'ler siliniyor..."
SUBNET1_ID=$(aws ec2 describe-subnets --region $REGION --query "Subnets[?contains(Tags[?Key=='Name'].Value, '${PROJECT_NAME}-rds-subnet1-${LATEST_TIMESTAMP}')].SubnetId" --output text)
SUBNET2_ID=$(aws ec2 describe-subnets --region $REGION --query "Subnets[?contains(Tags[?Key=='Name'].Value, '${PROJECT_NAME}-rds-subnet2-${LATEST_TIMESTAMP}')].SubnetId" --output text)

if [ ! -z "$SUBNET1_ID" ]; then
    aws ec2 delete-subnet --subnet-id "$SUBNET1_ID" --region $REGION
    print_success "✅ Subnet silindi: $SUBNET1_ID"
fi

if [ ! -z "$SUBNET2_ID" ]; then
    aws ec2 delete-subnet --subnet-id "$SUBNET2_ID" --region $REGION
    print_success "✅ Subnet silindi: $SUBNET2_ID"
fi

# 5. Route Table'ı bul ve sil
print_info "🗺️ Route Table siliniyor..."
ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --region $REGION --query "RouteTables[?contains(Tags[?Key=='Name'].Value, '${PROJECT_NAME}-rds-rt-${LATEST_TIMESTAMP}')].RouteTableId" --output text)
if [ ! -z "$ROUTE_TABLE_ID" ]; then
    aws ec2 delete-route-table --route-table-id "$ROUTE_TABLE_ID" --region $REGION
    print_success "✅ Route Table silindi: $ROUTE_TABLE_ID"
fi

# 6. Internet Gateway'ı bul ve sil
print_info "🌍 Internet Gateway siliniyor..."
IGW_ID=$(aws ec2 describe-internet-gateways --region $REGION --query "InternetGateways[?contains(Tags[?Key=='Name'].Value, '${PROJECT_NAME}-rds-igw-${LATEST_TIMESTAMP}')].InternetGatewayId" --output text)
if [ ! -z "$IGW_ID" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region $REGION
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region $REGION
    print_success "✅ Internet Gateway silindi: $IGW_ID"
fi

# 7. VPC'yi bul ve sil
print_info "🏗️ VPC siliniyor: $VPC_NAME"
VPC_ID=$(aws ec2 describe-vpcs --region $REGION --query "Vpcs[?contains(Tags[?Key=='Name'].Value, '$VPC_NAME')].VpcId" --output text)
if [ ! -z "$VPC_ID" ]; then
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --region $REGION
    print_success "✅ VPC silindi: $VPC_NAME ($VPC_ID)"
else
    print_warning "⚠️ VPC bulunamadı: $VPC_NAME"
fi

echo ""
print_success "🎉 RDS cleanup tamamlandı!"
print_success "✅ Tüm RDS kaynakları silindi"
print_info "💰 Maliyet kontrolü için AWS Billing Dashboard'ı kontrol edin"