#!/bin/bash
set -e

R='\033[0;31m'; G='\033[0;32m'; NC='\033[0m'

if [ -f ".deployment-info" ]; then
    source .deployment-info
    echo "Found: $BUCKET_NAME, $ECR_REPO_NAME in $AWS_REGION"
else
    # Deployment bilgisi yok, manuel giriş gerekli
    read -p "Region: " AWS_REGION
    read -p "Bucket: " BUCKET_NAME
    read -p "ECR Repo [mnist-training]: " ECR_REPO_NAME
    ECR_REPO_NAME=${ECR_REPO_NAME:-mnist-training}
fi

# Son onay (tüm kaynaklar silinecek)
echo -e "${R}⚠ Deleting all resources${NC}"
read -p "Continue? (y/n): " -n 1 -r; echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

aws sagemaker list-training-jobs --region "$AWS_REGION" --status-equals InProgress \
    --query "TrainingJobSummaries[?contains(TrainingJobName, 'mnist')].TrainingJobName" --output text 2>/dev/null | \
    xargs -I {} aws sagemaker stop-training-job --training-job-name {} --region "$AWS_REGION" 2>/dev/null || true

if aws s3 ls "s3://$BUCKET_NAME" --region "$AWS_REGION" &> /dev/null; then
    aws s3 rm "s3://$BUCKET_NAME" --recursive --region "$AWS_REGION" > /dev/null 2>&1
    aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null
    echo -e "${G}✓${NC} Deleted S3: $BUCKET_NAME"
fi

if aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" &> /dev/null; then
    aws ecr delete-repository --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION" --force > /dev/null 2>&1
    echo -e "${G}✓${NC} Deleted ECR: $ECR_REPO_NAME"
fi

rm -rf ./data model.tar.gz 2>/dev/null || true
rm -f .deployment-info .data-info 2>/dev/null || true

echo -e "${G}✓${NC} Cleanup complete"
