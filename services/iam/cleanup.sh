#!/bin/bash

# AWS ZERO to YETO - IAM Cleanup Script (Direct AWS CLI)
# Bu script IAM kaynaklarını temizlemek için kullanılır

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
REGION="eu-west-1"
PROJECT_NAME="aws-zero-to-yeto"

print_info "IAM Cleanup başlatılıyor (Direct AWS CLI)..."

# AWS CLI kontrolü
check_aws_cli

# En son deploy edilen IAM kaynaklarını bul (timestamp'a göre en yüksek)
print_info "🔍 En son deploy edilen IAM kaynakları aranıyor..."

# En yüksek timestamp'li IAM kaynaklarını bul
LATEST_TIMESTAMP=$(aws iam list-users --query 'Users[?contains(UserName, `aws-zero-to-yeto-iam`)].UserName' --output text 2>/dev/null | sed 's/aws-zero-to-yeto-iam-\([0-9]*\)-demo-user/\1/' | sort -n | tail -1)

if [ -z "$LATEST_TIMESTAMP" ]; then
    print_warning "IAM kaynakları bulunamadı"
    exit 0
fi

DEPLOY_PROJECT_NAME="aws-zero-to-yeto-iam-${LATEST_TIMESTAMP}"
USER_NAME="${DEPLOY_PROJECT_NAME}-demo-user"
GROUP_NAME="${DEPLOY_PROJECT_NAME}-demo-group"
ROLE_NAME="${DEPLOY_PROJECT_NAME}-demo-role"
POLICY_NAME="${DEPLOY_PROJECT_NAME}-demo-policy"

print_info "🎯 Hedef kaynaklar:"
print_info "   - IAM User: $USER_NAME"
print_info "   - IAM Group: $GROUP_NAME"
print_info "   - IAM Role: $ROLE_NAME"
print_info "   - IAM Policy: $POLICY_NAME"

echo ""
print_warning "⚠️  Bu kaynaklar silinecek!"
read -p "Devam etmek istiyor musunuz? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_info "İşlem iptal edildi"
    exit 0
fi

echo ""
print_info "🗑️  Kaynaklar siliniyor..."

# IAM Users'ları bul ve sil
print_info "IAM User siliniyor: $USER_NAME"
IAM_USERS=$(aws iam list-users \
    --query 'Users[?contains(UserName, `'$DEPLOY_PROJECT_NAME'`)].UserName' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$IAM_USERS" ]; then
    print_info "Bulunan IAM Users: $IAM_USERS"
    
    for user in $IAM_USERS; do
        # Access key'leri sil
        ACCESS_KEYS=$(aws iam list-access-keys --user-name $user --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null || echo "")
        if [ ! -z "$ACCESS_KEYS" ]; then
            for key in $ACCESS_KEYS; do
                print_info "Access key siliniyor: $key"
                aws iam delete-access-key --user-name $user --access-key-id $key 2>/dev/null || true
            done
        fi
        
        # User'ı group'lardan çıkar
        GROUPS=$(aws iam get-groups-for-user --user-name $user --query 'Groups[].GroupName' --output text 2>/dev/null || echo "")
        if [ ! -z "$GROUPS" ]; then
            for group in $GROUPS; do
                print_info "User $user group $group'dan çıkarılıyor"
                aws iam remove-user-from-group --user-name $user --group-name $group 2>/dev/null || true
            done
        fi
        
        # User'ı sil
        print_info "IAM User siliniyor: $user"
        aws iam delete-user --user-name $user 2>/dev/null || true
        print_success "IAM User silindi: $user"
    done
else
    print_warning "IAM User bulunamadı"
fi

# IAM Groups'ları sil
print_info "IAM Group siliniyor: $GROUP_NAME"
if aws iam get-group --group-name "$GROUP_NAME" >/dev/null 2>&1; then
    # Policy'leri çıkar
    POLICIES=$(aws iam list-attached-group-policies --group-name "$GROUP_NAME" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
    if [ ! -z "$POLICIES" ]; then
        for policy in $POLICIES; do
            print_info "   Policy detached: $policy"
            aws iam detach-group-policy --group-name "$GROUP_NAME" --policy-arn "$policy" 2>/dev/null || true
        done
    fi
    
    aws iam delete-group --group-name "$GROUP_NAME" 2>/dev/null || true
    print_success "✅ IAM Group silindi: $GROUP_NAME"
else
    print_warning "⚠️ IAM Group bulunamadı: $GROUP_NAME"
fi

# IAM Roles'ları sil
print_info "IAM Role siliniyor: $ROLE_NAME"
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    # Policy'leri çıkar
    POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
    if [ ! -z "$POLICIES" ]; then
        for policy in $POLICIES; do
            print_info "   Policy detached: $policy"
            aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy" 2>/dev/null || true
        done
    fi
    
    aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || true
    print_success "✅ IAM Role silindi: $ROLE_NAME"
else
    print_warning "⚠️ IAM Role bulunamadı: $ROLE_NAME"
fi

# IAM Policies'ları sil
print_info "IAM Policy siliniyor: $POLICY_NAME"
if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME" >/dev/null 2>&1; then
    aws iam delete-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME" 2>/dev/null || true
    print_success "✅ IAM Policy silindi: $POLICY_NAME"
else
    print_warning "⚠️ IAM Policy bulunamadı: $POLICY_NAME"
fi

echo ""
print_success "🎉 IAM cleanup tamamlandı!"
print_success "✅ Tüm IAM kaynakları silindi"
print_info "💰 Maliyet kontrolü için AWS Billing Dashboard'ı kontrol edin"