#!/bin/bash
set -e

G='\033[0;32m'; B='\033[0;34m'; NC='\033[0m'
info() { echo -e "${B}▶${NC} $1"; }
success() { echo -e "${G}✓${NC} $1"; }

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
python3 - << 'EOF'
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
DATA_PREPARED_DATE=$(date)
EOF

success "Data prepared and uploaded to s3://${BUCKET_NAME}/mnist-data/"
echo "Next: ./deploy.sh"
