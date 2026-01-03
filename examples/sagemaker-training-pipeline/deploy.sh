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
    warn "Data not prepared! Run ./prepare-data.sh first"
    read -p "Continue anyway? (y/n): " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && { echo "Run: ./prepare-data.sh"; exit 1; }
    
    # AWS Region girin (örnek: us-east-1, eu-west-1)
    read -p "Region: " AWS_REGION
    [ -z "$AWS_REGION" ] && { echo "Region required"; exit 1; }
    
    # S3 Bucket adı
    read -p "Bucket: " BUCKET_NAME
    [ -z "$BUCKET_NAME" ] && { echo "Bucket required"; exit 1; }
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
test_labels.npy', test_ds.targets.numpy())
]

s3 = boto3.client('s3')
for name, arr in data:
    buf = BytesIO()
    np.save(buf, arr)
    buf.seek(0)
    s3.upload_fileobj(buf, os.environ['BUCKET'], f"mnist-data/{name}")
EOF
export BUCKET=$BUCKET_NAME

info "Setting up ECR..."
aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" &> /dev/null || \
    aws ecr create-repository --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION" > /dev/null

ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:latest"

info "Building and pushing Docker image..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" > /dev/null
docker buildx build --platform linux/amd64 -t "$ECR_URI" --push . > /dev/null

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
