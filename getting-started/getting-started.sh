#!/bin/bash

# AWS ZERO to YETO - Environment Setup Script
# Bu script development ortamını kurmaya yardımcı olur

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

echo "🚀 AWS ZERO to YETO - Environment Setup"
echo "======================================"

# 1. System Check
print_info "📋 Sistem kontrol ediliyor..."

# Python check
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_success "Python 3 bulundu: $PYTHON_VERSION"
else
    print_error "Python 3 bulunamadı. Lütfen Python 3.8+ kurun."
    exit 1
fi

# AWS CLI check
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version | cut -d' ' -f1 | cut -d'/' -f2)
    print_success "AWS CLI bulundu: $AWS_VERSION"
else
    print_warning "AWS CLI bulunamadı. Kurulumu başlatılıyor..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install awscli
        else
            print_error "Homebrew bulunamadı. Manuel kurulum: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-mac.html"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf awscliv2.zip aws/
    else
        print_error "Desteklenmeyen işletim sistemi. Manuel kurulum gerekli."
        exit 1
    fi
    
    print_success "AWS CLI kuruldu"
fi

# 2. Python Dependencies
print_info "📦 Python paketleri kuruluyor..."
if [[ ! -d "venv" ]]; then
    print_info "Virtual environment oluşturuluyor..."
    python3 -m venv venv
fi
print_info "Virtual environment aktive ediliyor..."
source venv/bin/activate
pip install boto3 pandas requests

# 3. AWS Configuration Check
print_info "🔐 AWS konfigürasyonu kontrol ediliyor..."

if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    print_success "AWS kimlik doğrulaması başarılı"
    print_info "Account ID: $ACCOUNT_ID"
    print_info "User: $USER_ARN"
else
    print_warning "AWS kimlik bilgileri yapılandırılmamış"
    print_info "AWS konfigürasyonu başlatılıyor..."
    
    echo ""
    echo "AWS kimlik bilgilerinizi girin:"
    read -p "AWS Access Key ID: " ACCESS_KEY
    read -s -p "AWS Secret Access Key: " SECRET_KEY
    echo ""
    read -p "Default region (eu-west-1): " REGION
    REGION=${REGION:-eu-west-1}
    
    aws configure set aws_access_key_id "$ACCESS_KEY"
    aws configure set aws_secret_access_key "$SECRET_KEY"
    aws configure set default.region "$REGION"
    aws configure set default.output json
    
    print_success "AWS kimlik bilgileri kaydedildi"
fi

# 4. Region Check
CURRENT_REGION=$(aws configure get region)
print_info "Geçerli bölge: $CURRENT_REGION"

if [[ "$CURRENT_REGION" != "eu-west-1" ]]; then
    print_warning "Önerilen bölge eu-west-1, geçerli: $CURRENT_REGION"
    read -p "eu-west-1 olarak değiştirmek istiyor musunuz? (y/n): " change_region
    if [[ "$change_region" == "y" ]]; then
        aws configure set region eu-west-1
        print_success "Bölge eu-west-1 olarak değiştirildi"
    fi
fi

# 5. Free Tier Check
print_info "💰 Free Tier durumu kontrol ediliyor..."

# Account oluşturma tarihini kontrol et (basit)
ACCOUNT_AGE=$(aws iam get-account-summary --query 'SummaryMap.AccountMFAEnabled' --output text 2>/dev/null || echo "unknown")

if [[ "$ACCOUNT_AGE" != "unknown" ]]; then
    print_success "Free Tier durumu kontrol edilebilir"
    print_warning "⚠️  Free Tier limitleri:"

    echo "   - S3: 5GB depolama"
    echo "   - Lambda: 1M istek/ay"
    echo "   - RDS: 750 saat/ay (db.t3.micro)"
    echo "   - Bedrock: 5M token/ay"
else
    print_warning "Free Tier durumu kontrol edilemedi"
fi

# 6. Required IAM Permissions Check
print_info "🔐 IAM izinleri kontrol ediliyor..."

REQUIRED_SERVICES=("s3" "lambda" "ec2" "rds" "dynamodb" "iam" "cloudformation")
MISSING_PERMISSIONS=()

for service in "${REQUIRED_SERVICES[@]}"; do
    case $service in
        "s3")
            if ! aws s3 ls &> /dev/null; then
                MISSING_PERMISSIONS+=("S3")
            fi
            ;;
        "lambda")
            if ! aws lambda list-functions &> /dev/null; then
                MISSING_PERMISSIONS+=("Lambda")
            fi
            ;;
        "ec2")
            if ! aws ec2 describe-instances &> /dev/null; then
                MISSING_PERMISSIONS+=("EC2")
            fi
            ;;
    esac
done

if [[ ${#MISSING_PERMISSIONS[@]} -eq 0 ]]; then
    print_success "Temel IAM izinleri mevcut"
else
    print_warning "Eksik izinler: ${MISSING_PERMISSIONS[*]}"
    print_info "Admin izinleri önerilir (test ortamı için)"
fi

# 7. Create helpful aliases
print_info "🔧 Yararlı alias'lar oluşturuluyor..."

ALIAS_FILE="$HOME/.aws_zero_to_yeto_aliases"
cat > "$ALIAS_FILE" << 'EOF'
# AWS ZERO to YETO - Helpful Aliases
alias awsid='aws sts get-caller-identity'
alias awsregion='aws configure get region'
alias s3ls='aws s3 ls'
alias ec2ls='aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress]" --output table'
alias lambdals='aws lambda list-functions --query "Functions[*].[FunctionName,Runtime,LastModified]" --output table'
alias rdsls='aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine]" --output table'
alias billing='aws ce get-cost-and-usage --time-period Start=$(date -d "30 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) --granularity MONTHLY --metrics BlendedCost'

# Quick cleanup functions
cleanup_s3() {
    echo "S3 buckets with 'zero-to-yeto' in name:"
    aws s3 ls | grep zero-to-yeto
}

cleanup_lambda() {
    echo "Lambda functions with 'zero-to-yeto' in name:"
    aws lambda list-functions --query "Functions[?contains(FunctionName, 'zero-to-yeto')].[FunctionName]" --output table
}
EOF

# Add to shell profile
if [[ -f "$HOME/.bashrc" ]]; then
    echo "source $ALIAS_FILE" >> "$HOME/.bashrc"
    print_success "Aliases eklendi: ~/.bashrc"
elif [[ -f "$HOME/.zshrc" ]]; then
    echo "source $ALIAS_FILE" >> "$HOME/.zshrc"
    print_success "Aliases eklendi: ~/.zshrc"
fi

# 8. Create useful scripts directory
print_info "📁 Scripts dizini hazırlanıyor..."
mkdir -p "$HOME/.aws-zero-to-yeto"

# Quick deployment script
cat > "$HOME/.aws-zero-to-yeto/quick-deploy.sh" << 'EOF'
#!/bin/bash
# Quick deployment helper

echo "🚀 AWS ZERO to YETO - Quick Deploy"
echo "Available examples:"
echo "1. S3 + Lambda API"
echo "2. S3 + Lambda API"
echo "3. Bedrock Chat"

read -p "Select example (1-3): " choice

case $choice in
    1)
        cd examples/s3-lambda-api && ./deploy.sh
        ;;
    2)
        cd examples/ec2-rds-web && ./deploy.sh
        ;;
    3)
        cd examples/bedrock-s3-chat && ./deploy.sh
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
EOF

chmod +x "$HOME/.aws-zero-to-yeto/quick-deploy.sh"

# 9. Final Summary
echo ""
echo "🎉 Setup tamamlandı!"
echo "==================="
print_success "✅ Python 3 hazır"
print_success "✅ AWS CLI hazır"
print_success "✅ Boto3 kuruldu"
print_success "✅ AWS kimlik bilgileri yapılandırıldı"
print_success "✅ Yararlı aliases oluşturuldu"

echo ""
print_info "📋 Sonraki adımlar:"
echo "1. Yeni terminal açın (aliases için)"
echo "2. 'cd docs && cat getting-started.md' ile rehberi okuyun"
echo "3. İlk projenizi seçin ve çalıştırın"
echo "4. Örnek: 'cd examples/s3-lambda-api && ./deploy.sh'"

echo ""
print_warning "⚠️  Önemli hatırlatmalar:"
echo "- Free Tier limitlerini aşmayın"
echo "- Her proje sonrası './cleanup.sh' çalıştırın"
echo "- Billing dashboard'ı düzenli kontrol edin"

echo ""
print_info "🔗 Yararlı komutlar:"
echo "- awsid          : AWS kimlik bilgileri"
echo "- s3ls           : S3 buckets listesi"

echo "- billing        : Son 30 gün maliyet"
echo "- cleanup_s3     : S3 temizlik yardımcısı"

echo ""
print_success "Başarılar! AWS öğrenme yolculuğunuz başlasın! 🚀"
