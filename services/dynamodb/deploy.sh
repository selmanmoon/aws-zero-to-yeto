#!/bin/bash

# DynamoDB Demo Setup
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

TABLE_NAME="aws-zero-to-yeto-demo-$(date +%s)"

print_info "🗄️ DynamoDB Demo Setup..."

# DynamoDB table oluştur
aws dynamodb create-table \
    --table-name $TABLE_NAME \
    --attribute-definitions \
        AttributeName=id,AttributeType=S \
        AttributeName=timestamp,AttributeType=N \
    --key-schema \
        AttributeName=id,KeyType=HASH \
        AttributeName=timestamp,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=Project,Value=aws-zero-to-yeto

print_success "DynamoDB table oluşturuldu: $TABLE_NAME"

# Table'ın hazır olmasını bekle
print_info "Table'ın hazır olması bekleniyor..."
aws dynamodb wait table-exists --table-name $TABLE_NAME

# Örnek veri ekle
aws dynamodb put-item \
    --table-name $TABLE_NAME \
    --item '{
        "id": {"S": "user-001"},
        "timestamp": {"N": "'$(date +%s)'"},
        "name": {"S": "Ahmet Yılmaz"},
        "email": {"S": "ahmet@example.com"},
        "age": {"N": "28"}
    }'

print_success "Örnek veri eklendi"

# Deployment bilgilerini README'ye yaz
print_info "📝 Deployment bilgileri README'de mevcut"

print_success "🎉 DynamoDB demo hazır!"
print_info "📋 Table: $TABLE_NAME"
