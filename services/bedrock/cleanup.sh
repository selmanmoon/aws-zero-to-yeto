#!/bin/bash

# AWS ZERO to YETO - Bedrock Cleanup Script (Direct AWS CLI)
# Bu script Bedrock kaynaklarını temizlemek için kullanılır

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

print_info "Bedrock Cleanup başlatılıyor (Direct AWS CLI)..."

# AWS CLI kontrolü
check_aws_cli

# Bedrock Custom Models'ları bul ve sil
print_info "Bedrock Custom Models aranıyor..."
CUSTOM_MODELS=$(aws bedrock list-custom-models \
    --query 'customModelSummaries[?contains(modelName, `'$PROJECT_NAME'`)].modelId' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$CUSTOM_MODELS" ]; then
    print_info "Bulunan Custom Models: $CUSTOM_MODELS"
    
    for model in $CUSTOM_MODELS; do
        print_info "Custom model siliniyor: $model"
        aws bedrock delete-custom-model --model-id $model --region $REGION 2>/dev/null || true
        print_success "Custom model silindi: $model"
    done
else
    print_warning "Custom model bulunamadı"
fi

# Bedrock Model Invocation Logs'ları bul ve sil
print_info "Bedrock Model Invocation Logs aranıyor..."
INVOCATION_LOGS=$(aws bedrock list-model-invocation-logs \
    --query 'modelInvocationLogSummaries[?contains(modelId, `'$PROJECT_NAME'`)].modelId' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$INVOCATION_LOGS" ]; then
    print_info "Bulunan Model Invocation Logs: $INVOCATION_LOGS"
    
    for log in $INVOCATION_LOGS; do
        print_info "Model invocation log siliniyor: $log"
        aws bedrock delete-model-invocation-log --model-id $log --region $REGION 2>/dev/null || true
        print_success "Model invocation log silindi: $log"
    done
else
    print_warning "Model invocation log bulunamadı"
fi

# Bedrock Guardrails'ları bul ve sil
print_info "Bedrock Guardrails aranıyor..."
GUARDRAILS=$(aws bedrock list-guardrails \
    --query 'guardrails[?contains(name, `'$PROJECT_NAME'`)].id' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$GUARDRAILS" ]; then
    print_info "Bulunan Guardrails: $GUARDRAILS"
    
    for guardrail in $GUARDRAILS; do
        print_info "Guardrail siliniyor: $guardrail"
        aws bedrock delete-guardrail --id $guardrail --region $REGION 2>/dev/null || true
        print_success "Guardrail silindi: $guardrail"
    done
else
    print_warning "Guardrail bulunamadı"
fi

# Bedrock Knowledge Bases'ları bul ve sil
print_info "Bedrock Knowledge Bases aranıyor..."
KNOWLEDGE_BASES=$(aws bedrock list-knowledge-bases \
    --query 'knowledgeBaseSummaries[?contains(name, `'$PROJECT_NAME'`)].knowledgeBaseId' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$KNOWLEDGE_BASES" ]; then
    print_info "Bulunan Knowledge Bases: $KNOWLEDGE_BASES"
    
    for kb in $KNOWLEDGE_BASES; do
        print_info "Knowledge base siliniyor: $kb"
        aws bedrock delete-knowledge-base --knowledge-base-id $kb --region $REGION 2>/dev/null || true
        print_success "Knowledge base silindi: $kb"
    done
else
    print_warning "Knowledge base bulunamadı"
fi

# Bedrock Agents'ları bul ve sil
print_info "Bedrock Agents aranıyor..."
AGENTS=$(aws bedrock list-agents \
    --query 'agentSummaries[?contains(agentName, `'$PROJECT_NAME'`)].agentId' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$AGENTS" ]; then
    print_info "Bulunan Agents: $AGENTS"
    
    for agent in $AGENTS; do
        print_info "Agent siliniyor: $agent"
        aws bedrock delete-agent --agent-id $agent --region $REGION 2>/dev/null || true
        print_success "Agent silindi: $agent"
    done
else
    print_warning "Agent bulunamadı"
fi

print_success "🎉 Bedrock cleanup tamamlandı!"
print_info "Tüm Bedrock custom models, logs, guardrails, knowledge bases ve agents temizlendi"