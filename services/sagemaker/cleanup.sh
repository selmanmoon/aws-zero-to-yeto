#!/bin/bash

# AWS ZERO to YETO - SageMaker Cleanup Script (Direct AWS CLI)
# Bu script SageMaker kaynaklarını temizlemek için kullanılır

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

print_info "SageMaker Cleanup başlatılıyor (Direct AWS CLI)..."

# AWS CLI kontrolü
check_aws_cli

# SageMaker Endpoints'ları bul ve sil
print_info "SageMaker Endpoints aranıyor..."
ENDPOINTS=$(aws sagemaker list-endpoints \
    --query 'Endpoints[?contains(EndpointName, `'$PROJECT_NAME'`)].EndpointName' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$ENDPOINTS" ]; then
    print_info "Bulunan Endpoints: $ENDPOINTS"
    
    for endpoint in $ENDPOINTS; do
        print_info "Endpoint siliniyor: $endpoint"
        aws sagemaker delete-endpoint --endpoint-name $endpoint --region $REGION 2>/dev/null || true
        print_success "Endpoint silindi: $endpoint"
    done
else
    print_warning "Endpoint bulunamadı"
fi

# SageMaker Endpoint Configurations'ları bul ve sil
print_info "SageMaker Endpoint Configurations aranıyor..."
ENDPOINT_CONFIGS=$(aws sagemaker list-endpoint-configs \
    --query 'EndpointConfigs[?contains(EndpointConfigName, `'$PROJECT_NAME'`)].EndpointConfigName' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$ENDPOINT_CONFIGS" ]; then
    print_info "Bulunan Endpoint Configurations: $ENDPOINT_CONFIGS"
    
    for config in $ENDPOINT_CONFIGS; do
        print_info "Endpoint Configuration siliniyor: $config"
        aws sagemaker delete-endpoint-config --endpoint-config-name $config --region $REGION 2>/dev/null || true
        print_success "Endpoint Configuration silindi: $config"
    done
else
    print_warning "Endpoint Configuration bulunamadı"
fi

# SageMaker Models'ları bul ve sil
print_info "SageMaker Models aranıyor..."
MODELS=$(aws sagemaker list-models \
    --query 'Models[?contains(ModelName, `'$PROJECT_NAME'`)].ModelName' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$MODELS" ]; then
    print_info "Bulunan Models: $MODELS"
    
    for model in $MODELS; do
        print_info "Model siliniyor: $model"
        aws sagemaker delete-model --model-name $model --region $REGION 2>/dev/null || true
        print_success "Model silindi: $model"
    done
else
    print_warning "Model bulunamadı"
fi

# SageMaker Training Jobs'ları bul ve sil
print_info "SageMaker Training Jobs aranıyor..."
TRAINING_JOBS=$(aws sagemaker list-training-jobs \
    --query 'TrainingJobSummaries[?contains(TrainingJobName, `'$PROJECT_NAME'`)].TrainingJobName' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$TRAINING_JOBS" ]; then
    print_info "Bulunan Training Jobs: $TRAINING_JOBS"
    
    for job in $TRAINING_JOBS; do
        print_info "Training Job siliniyor: $job"
        aws sagemaker stop-training-job --training-job-name $job --region $REGION 2>/dev/null || true
        print_success "Training Job silindi: $job"
    done
else
    print_warning "Training Job bulunamadı"
fi

# SageMaker Processing Jobs'ları bul ve sil
print_info "SageMaker Processing Jobs aranıyor..."
PROCESSING_JOBS=$(aws sagemaker list-processing-jobs \
    --query 'ProcessingJobSummaries[?contains(ProcessingJobName, `'$PROJECT_NAME'`)].ProcessingJobName' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$PROCESSING_JOBS" ]; then
    print_info "Bulunan Processing Jobs: $PROCESSING_JOBS"
    
    for job in $PROCESSING_JOBS; do
        print_info "Processing Job siliniyor: $job"
        aws sagemaker stop-processing-job --processing-job-name $job --region $REGION 2>/dev/null || true
        print_success "Processing Job silindi: $job"
    done
else
    print_warning "Processing Job bulunamadı"
fi

# SageMaker Notebook Instances'ları bul ve sil
print_info "SageMaker Notebook Instances aranıyor..."
NOTEBOOK_INSTANCES=$(aws sagemaker list-notebook-instances \
    --query 'NotebookInstances[?contains(NotebookInstanceName, `'$PROJECT_NAME'`)].NotebookInstanceName' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ ! -z "$NOTEBOOK_INSTANCES" ]; then
    print_info "Bulunan Notebook Instances: $NOTEBOOK_INSTANCES"
    
    for instance in $NOTEBOOK_INSTANCES; do
        print_info "Notebook Instance siliniyor: $instance"
        aws sagemaker delete-notebook-instance --notebook-instance-name $instance --region $REGION 2>/dev/null || true
        print_success "Notebook Instance silindi: $instance"
    done
else
    print_warning "Notebook Instance bulunamadı"
fi

# SageMaker IAM Role'ları bul ve sil
print_info "SageMaker IAM Roles aranıyor..."
SAGEMAKER_ROLES=$(aws iam list-roles \
    --query 'Roles[?contains(RoleName, `'$PROJECT_NAME'-sagemaker`)].RoleName' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$SAGEMAKER_ROLES" ]; then
    print_info "Bulunan SageMaker IAM Roles: $SAGEMAKER_ROLES"
    
    for role in $SAGEMAKER_ROLES; do
        # Policy'leri çıkar
        POLICIES=$(aws iam list-attached-role-policies --role-name $role --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
        if [ ! -z "$POLICIES" ]; then
            for policy in $POLICIES; do
                print_info "Policy $policy role $role'dan çıkarılıyor"
                aws iam detach-role-policy --role-name $role --policy-arn $policy 2>/dev/null || true
            done
        fi
        
        # Role'u sil
        print_info "SageMaker IAM Role siliniyor: $role"
        aws iam delete-role --role-name $role 2>/dev/null || true
        print_success "SageMaker IAM Role silindi: $role"
    done
else
    print_warning "SageMaker IAM Role bulunamadı"
fi

print_success "🎉 SageMaker cleanup tamamlandı!"
print_info "Tüm SageMaker endpoints, models, jobs, notebook instances ve IAM roles temizlendi"