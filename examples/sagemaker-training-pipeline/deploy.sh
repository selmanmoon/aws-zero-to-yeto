#!/bin/bash
set -e

G='\033[0;32m'; B='\033[0;34m'; Y='\033[1;33m'; NC='\033[0m'
info() { echo -e "${B}▶${NC} $1"; }
success() { echo -e "${G}✓${NC} $1"; }
warn() { echo -e "${Y}⚠${NC} $1"; }

# Data hazırlığı yapılmış mı kontrol et
if [ -f ".data-info" ]; then
    source .data-info
    info "Using existing data: s3://${BUCKET_NAME}/mnist-data/"
else
    warn "Data not prepared! Preparing data first..."
    
    # AWS Region girin (örnek: us-east-1, eu-west-1)
    read -p "Region: " AWS_REGION
    [ -z "$AWS_REGION" ] && { echo "Region required"; exit 1; }
    
    # S3 Bucket adı (boş bırakırsa otomatik isim verilir)
    read -p "Bucket [mnist-training-$(date +%Y%m%d)]: " BUCKET_NAME
    BUCKET_NAME=${BUCKET_NAME:-mnist-training-$(date +%Y%m%d)}
    
    info "Creating S3 bucket..."
    if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
        [ "$AWS_REGION" = "us-east-1" ] && \
            aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" || \
            aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    
    export BUCKET=$BUCKET_NAME
    export AWS_DEFAULT_REGION=$AWS_REGION
    
    info "Downloading and uploading MNIST data..."
    python - << 'EOF'
import torch, torchvision, numpy as np, boto3
from torchvision import transforms
from io import BytesIO
import os

transform = transforms.Compose([transforms.ToTensor()])
train_ds = torchvision.datasets.MNIST(root='./data', train=True, download=True, transform=transform)
test_ds = torchvision.datasets.MNIST(root='./data', train=False, download=True, transform=transform)

data = [
    ('train_data.npy', train_ds.data.numpy().astype('float32') / 255.0),
    ('train_labels.npy', train_ds.targets.numpy()),
    ('test_data.npy', test_ds.data.numpy().astype('float32') / 255.0),
    ('test_labels.npy', test_ds.targets.numpy())
]

s3 = boto3.client('s3')
for name, arr in data:
    buf = BytesIO()
    np.save(buf, arr)
    buf.seek(0)
    s3.upload_fileobj(buf, os.environ['BUCKET'], f"mnist-data/{name}")
    print(f"✓ Uploaded {name}")
EOF

    rm -rf ./data 2>/dev/null || true
    
    cat > .data-info << EOF
AWS_REGION=$AWS_REGION
BUCKET_NAME=$BUCKET_NAME
DATA_PREPARED_DATE="$(date)"
EOF
    
    success "Data prepared and uploaded to s3://${BUCKET_NAME}/mnist-data/"
fi

# Configuration
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO_NAME="sagemaker-mnist"
TRAINING_JOB_NAME="mnist-training-$(date +%s)"
SAGEMAKER_ROLE_NAME="SageMakerExecutionRole"
INSTANCE_TYPE="ml.m5.large"

# Get or create SageMaker role
ROLE_ARN=$(aws iam get-role --role-name "$SAGEMAKER_ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || {
    info "Creating SageMaker execution role..."
    aws iam create-role --role-name "$SAGEMAKER_ROLE_NAME" \
        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"sagemaker.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
        --query 'Role.Arn' --output text
    aws iam attach-role-policy --role-name "$SAGEMAKER_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess
    sleep 10
})

info "Setting up ECR..."
aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" &> /dev/null || \
    aws ecr create-repository --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION" > /dev/null

ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:latest"

info "Building and pushing Docker image..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" > /dev/null
docker buildx build --platform linux/amd64 -t "$ECR_URI" --push .

info "Starting training job..."
aws sagemaker create-training-job \
    --training-job-name "$TRAINING_JOB_NAME" \
    --algorithm-specification TrainingImage="$ECR_URI",TrainingInputMode=File \
    --role-arn "$ROLE_ARN" \
    --input-data-config '[{"ChannelName":"training","DataSource":{"S3DataSource":{"S3DataType":"S3Prefix","S3Uri":"s3://'${BUCKET_NAME}'/mnist-data/","S3DataDistributionType":"FullyReplicated"}},"ContentType":"application/x-npy"}]' \
    --output-data-config S3OutputPath="s3://${BUCKET_NAME}/mnist-output" \
    --resource-config InstanceType="$INSTANCE_TYPE",InstanceCount=1,VolumeSizeInGB=30 \
    --stopping-condition MaxRuntimeInSeconds=3600 \
    --region "$AWS_REGION" > /dev/null

cat > .deployment-info << EOF
AWS_REGION=$AWS_REGION
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
BUCKET_NAME=$BUCKET_NAME
ECR_REPO_NAME=$ECR_REPO_NAME
TRAINING_JOB_NAME=$TRAINING_JOB_NAME
SAGEMAKER_ROLE_NAME=$SAGEMAKER_ROLE_NAME
EOF

success "Deployed: $TRAINING_JOB_NAME"
echo "Monitor: aws sagemaker describe-training-job --training-job-name $TRAINING_JOB_NAME"
echo "Cleanup: ./cleanup.sh"
