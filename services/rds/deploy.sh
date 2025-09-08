#!/bin/bash

# AWS ZERO to YETO - RDS Deployment Script (Direct AWS CLI)
# Bu script RDS örneklerini Direct AWS CLI ile deploy etmek için kullanılır

set -e  # Hata durumunda script'i durdur

# Renkli çıktı için fonksiyonlar
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# AWS CLI kontrolü
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI kurulu değil. Lütfen önce AWS CLI'yi kurun."
        exit 1
    fi
    
    # AWS kimlik bilgilerini kontrol et
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS kimlik bilgileri yapılandırılmamış. 'aws configure' komutunu çalıştırın."
        exit 1
    fi
    
    print_success "AWS CLI ve kimlik bilgileri hazır"
}

# Değişkenler
PROJECT_NAME="aws-zero-to-yeto-rds"
REGION="eu-west-1"
TIMESTAMP=$(date +%s)
VPC_NAME="${PROJECT_NAME}-vpc-${TIMESTAMP}"
DB_SUBNET_GROUP_NAME="${PROJECT_NAME}-subnet-group-${TIMESTAMP}"
SECURITY_GROUP_NAME="${PROJECT_NAME}-sg-${TIMESTAMP}"
DB_INSTANCE_IDENTIFIER="${PROJECT_NAME}-mysql-${TIMESTAMP}"

# Database configurations
DB_INSTANCE_CLASS="db.t3.micro"  # Free Tier
STORAGE_SIZE="20"  # GB
DB_ENGINE="mysql"
ENGINE_VERSION="8.0.43"
MASTER_USERNAME="admin"
MASTER_PASSWORD="SecureMySQL123!"
DB_PORT="3306"

print_info "RDS Deployment başlatılıyor (Direct AWS CLI)..."
print_info "Bölge: $REGION"
print_info "DB Instance: $DB_INSTANCE_IDENTIFIER"

# AWS CLI kontrolü
check_aws_cli

# VPC oluştur
print_info "VPC oluşturuluyor..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $REGION --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME Key=Project,Value=$PROJECT_NAME --region $REGION
print_success "VPC oluşturuldu: $VPC_ID"

# VPC DNS ayarlarını etkinleştir
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames --region $REGION
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support --region $REGION

# Internet Gateway oluştur
print_info "Internet Gateway oluşturuluyor..."
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value="${PROJECT_NAME}-igw-${TIMESTAMP}" --region $REGION
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION
print_success "Internet Gateway oluşturuldu: $IGW_ID"

# Availability Zone'ları al
AZ1=$(aws ec2 describe-availability-zones --region $REGION --query 'AvailabilityZones[0].ZoneName' --output text)
AZ2=$(aws ec2 describe-availability-zones --region $REGION --query 'AvailabilityZones[1].ZoneName' --output text)

# İlk Public Subnet oluştur
print_info "İlk subnet oluşturuluyor..."
SUBNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone $AZ1 --region $REGION --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET1_ID --tags Key=Name,Value="${PROJECT_NAME}-subnet1-${TIMESTAMP}" --region $REGION
print_success "İlk subnet oluşturuldu: $SUBNET1_ID"

# İkinci Public Subnet oluştur (RDS için minimum 2 AZ gerekli)
print_info "İkinci subnet oluşturuluyor..."
SUBNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone $AZ2 --region $REGION --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET2_ID --tags Key=Name,Value="${PROJECT_NAME}-subnet2-${TIMESTAMP}" --region $REGION
print_success "İkinci subnet oluşturuldu: $SUBNET2_ID"

# Route Table oluştur
print_info "Route Table oluşturuluyor..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $ROUTE_TABLE_ID --tags Key=Name,Value="${PROJECT_NAME}-rt-${TIMESTAMP}" --region $REGION
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
aws ec2 associate-route-table --subnet-id $SUBNET1_ID --route-table-id $ROUTE_TABLE_ID --region $REGION
aws ec2 associate-route-table --subnet-id $SUBNET2_ID --route-table-id $ROUTE_TABLE_ID --region $REGION
print_success "Route Table oluşturuldu: $ROUTE_TABLE_ID"

# Security Group oluştur
print_info "Security Group oluşturuluyor..."
SG_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description "Security group for RDS database" --vpc-id $VPC_ID --region $REGION --query 'GroupId' --output text)
aws ec2 create-tags --resources $SG_ID --tags Key=Name,Value=$SECURITY_GROUP_NAME --region $REGION

# Security Group kuralları ekle (MySQL port)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port $DB_PORT --cidr 10.0.0.0/16 --region $REGION
print_success "Security Group oluşturuldu: $SG_ID"

# DB Subnet Group oluştur
print_info "DB Subnet Group oluşturuluyor..."
aws rds create-db-subnet-group \
    --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
    --db-subnet-group-description "Subnet group for RDS database" \
    --subnet-ids $SUBNET1_ID $SUBNET2_ID \
    --tags Key=Name,Value=$DB_SUBNET_GROUP_NAME Key=Project,Value=$PROJECT_NAME \
    --region $REGION
print_success "DB Subnet Group oluşturuldu: $DB_SUBNET_GROUP_NAME"

# RDS Instance oluştur
print_info "RDS Instance oluşturuluyor..."
aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --db-instance-class $DB_INSTANCE_CLASS \
    --engine $DB_ENGINE \
    --engine-version $ENGINE_VERSION \
    --master-username $MASTER_USERNAME \
    --master-user-password $MASTER_PASSWORD \
    --allocated-storage $STORAGE_SIZE \
    --storage-type gp2 \
    --vpc-security-group-ids $SG_ID \
    --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
    --backup-retention-period 7 \
    --no-multi-az \
    --auto-minor-version-upgrade \
    --publicly-accessible \
    --port $DB_PORT \
    --region $REGION \
    --tags Key=Name,Value=$DB_INSTANCE_IDENTIFIER Key=Project,Value=$PROJECT_NAME

print_success "RDS Instance oluşturma başlatıldı: $DB_INSTANCE_IDENTIFIER"

# Instance'ın hazır olmasını bekle
print_info "RDS Instance'ın hazır olması bekleniyor (bu işlem 10-15 dakika sürebilir)..."
aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_IDENTIFIER --region $REGION

# Endpoint bilgisini al
DB_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --region $REGION \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

print_success "RDS Instance hazır! Endpoint: $DB_ENDPOINT"

# Deployment bilgilerini kaydet

print_success "🎉 RDS deployment tamamlandı (Direct AWS CLI)!"
print_info "DB Instance: $DB_INSTANCE_IDENTIFIER"
print_info "DB Endpoint: $DB_ENDPOINT"
print_info "Username: $MASTER_USERNAME"
print_info "Password: $MASTER_PASSWORD"
print_info "Port: $DB_PORT"
print_info "Deployment bilgileri README'de mevcut"

print_warning "⚠️  Bu RDS instance ücretli bir kaynaktır. Free Tier limitlerini kontrol edin."
print_warning "⚠️  Database password'unu güvenli bir yerde saklayın."

echo ""
print_info "Test komutları:"
echo "  mysql -h $DB_ENDPOINT -P $DB_PORT -u $MASTER_USERNAME -p"
echo "  aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_IDENTIFIER --region $REGION"