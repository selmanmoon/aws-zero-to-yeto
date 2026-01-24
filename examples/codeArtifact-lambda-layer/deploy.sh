#!/bin/bash

# ============================================================================
# PPTX to PDF Converter - AWS Deployment Script (Cross-Platform)
# ============================================================================

set -e  # Exit on error

# ============================================================================
# CROSS-PLATFORM COMPATIBILITY CHECKS
# ============================================================================

# 1. Detect Python command
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "❌ Error: Python is not installed or not in PATH."
    exit 1
fi

# 2. Check for Zip
if ! command -v zip &> /dev/null; then
    echo "❌ Error: 'zip' utility is missing."
    echo "   Windows (Git Bash): Download zip from: https://sourceforge.net/projects/gnuwin32/files/zip/3.0/zip-3.0-bin.zip/download"
    echo "   Mac/Linux: Install via package manager (brew/apt/yum)."
    exit 1
fi

echo "✅ Using Python command: $PYTHON_CMD"

# ============================================================================
# CONFIGURATION
# ============================================================================

echo "🔧 Loading configuration..."

REGION="us-east-1"
BUCKET_NAME="pptx-to-pdf-converter-$(date +%s)"
CODEARTIFACT_DOMAIN="pptx-converter-domain"
CODEARTIFACT_REPO="pptx-converter-repo"
CONVERTER_FUNCTION="pptx-converter-function"
DASHBOARD_FUNCTION="pptx-dashboard-function"
LAYER_NAME="pptx-converter-layer"
LAMBDA_RUNTIME="python3.11"
CONVERTER_MEMORY=2048
DASHBOARD_MEMORY=512
LAMBDA_TIMEOUT=300
ROLE_NAME="pptx-converter-lambda-role"
TAGS="Project=PPTXConverter,Environment=Production"

echo "✅ Configuration loaded"
echo "   Region: $REGION"
echo "   Bucket: $BUCKET_NAME"
echo ""

# ============================================================================
# STEP 1: CODEARTIFACT
# ============================================================================

echo "============================================"
echo "📦 STEP 1: Setting up CodeArtifact"
echo "============================================"

aws codeartifact create-domain --domain "$CODEARTIFACT_DOMAIN" --region "$REGION" --tags "key=Project,value=PPTXConverter" 2>/dev/null || echo "   Domain already exists..."
aws codeartifact create-repository --domain "$CODEARTIFACT_DOMAIN" --repository "$CODEARTIFACT_REPO" --region "$REGION" 2>/dev/null || echo "   Repository already exists..."
aws codeartifact associate-external-connection --domain "$CODEARTIFACT_DOMAIN" --repository "$CODEARTIFACT_REPO" --external-connection "public:pypi" --region "$REGION" 2>/dev/null || echo "   Connection already exists..."

echo "✅ CodeArtifact setup complete"

# ============================================================================
# STEP 2: LAMBDA LAYER (CROSS-PLATFORM BUILD)
# ============================================================================

echo ""
echo "============================================"
echo "📚 STEP 2: Creating Lambda Layer"
echo "============================================"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# DÜZELTME 1: /tmp yerine bulunduğumuz dizinde klasör açıyoruz
LAYER_DIR="temp_layer_build"
# Temiz başlangıç yapalım
rm -rf "$LAYER_DIR"
rm -f layer.zip

echo "🔧 Using build directory: $LAYER_DIR"

echo "🔑 Getting CodeArtifact Token..."
AUTH_TOKEN=$(aws codeartifact get-authorization-token \
    --domain "$CODEARTIFACT_DOMAIN" \
    --domain-owner "$AWS_ACCOUNT_ID" \
    --region "$REGION" \
    --query authorizationToken \
    --output text)

ENDPOINT=$(aws codeartifact get-repository-endpoint \
    --domain "$CODEARTIFACT_DOMAIN" \
    --repository "$CODEARTIFACT_REPO" \
    --format pypi \
    --region "$REGION" \
    --query repositoryEndpoint \
    --output text | sed 's/https:\/\///')

FULL_CODEARTIFACT_URL="https://aws:$AUTH_TOKEN@$ENDPOINT"

mkdir -p "$LAYER_DIR/python"

echo "📥 Installing libraries (Forcing Linux x86_64 binaries)..."
pip install \
    --target "$LAYER_DIR/python" \
    --platform manylinux2014_x86_64 \
    --implementation cp \
    --python-version 3.11 \
    --only-binary=:all: \
    --upgrade \
    --index-url "${FULL_CODEARTIFACT_URL}simple/" \
    --extra-index-url "https://pypi.org/simple/" \
    python-pptx reportlab \
    --quiet

echo "📦 Creating layer ZIP..."
cd "$LAYER_DIR"

# Zip işlemini yapıyoruz
python -c "import shutil; shutil.make_archive('layer', 'zip', root_dir='.')"

# DÜZELTME 2: Zip dosyasını ana dizine taşıyoruz ki AWS CLI kolay bulsun
mv layer.zip ../layer.zip
cd ..

# Dosya kontrolü
if [ ! -f "layer.zip" ]; then
    echo "❌ ERROR: layer.zip was not created!"
    exit 1
fi

echo "🚀 Publishing Layer..."
# DÜZELTME 3: fileb://layer.zip diyerek doğrudan yanındaki dosyayı gösteriyoruz
LAYER_VERSION_ARN=$(aws lambda publish-layer-version --layer-name "$LAYER_NAME" --description "PPTX to PDF Libs" --zip-file "fileb://layer.zip" --compatible-runtimes "$LAMBDA_RUNTIME" --region "$REGION" --query 'LayerVersionArn' --output text)

echo "✅ Layer published: $LAYER_VERSION_ARN"

# Temizlik
rm -rf "$LAYER_DIR"
rm -f layer.zip

# ============================================================================
# STEP 3: IAM ROLE
# ============================================================================

echo ""
echo "============================================"
echo "🔐 STEP 3: Creating IAM Role"
echo "============================================"

TRUST_POLICY='{"Version": "2012-10-17","Statement": [{"Effect": "Allow","Principal": {"Service": "lambda.amazonaws.com"},"Action": "sts:AssumeRole"}]}'

aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document "$TRUST_POLICY" --region "$REGION" 2>/dev/null || echo "   Role already exists..."

# S3 Policy
S3_POLICY='{"Version": "2012-10-17","Statement": [{"Effect": "Allow","Action": ["s3:GetObject","s3:PutObject","s3:ListBucket"],"Resource": ["arn:aws:s3:::'"$BUCKET_NAME"'","arn:aws:s3:::'"$BUCKET_NAME"'/*"]}]}'

aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name "S3AccessPolicy" --policy-document "$S3_POLICY" --region "$REGION"
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" --region "$REGION" 2>/dev/null || true

CF_INVALIDATION_POLICY='{"Version": "2012-10-17","Statement": [{"Effect": "Allow","Action": "cloudfront:CreateInvalidation","Resource": "*"}]}'
echo "🔑 Adding CloudFront Invalidation permission to Role..."
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name "CFInvalidationPolicy" --policy-document "$CF_INVALIDATION_POLICY" --region "$REGION"


echo "⏳ Waiting for IAM propagation..."
sleep 60
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

# ============================================================================
# STEP 4: S3 BUCKET
# ============================================================================

echo ""
echo "============================================"
echo "🪣 STEP 4: Creating S3 Bucket"
echo "============================================"

if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
fi

aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" --region "$REGION"

aws s3api put-object --bucket "$BUCKET_NAME" --key "pptxs/" --region "$REGION"
aws s3api put-object --bucket "$BUCKET_NAME" --key "pdfs/" --region "$REGION"
aws s3api put-object --bucket "$BUCKET_NAME" --key "metadata/" --region "$REGION"

# ============================================================================
# STEP 5: CLOUDFRONT + OAC
# ============================================================================

echo ""
echo "============================================"
echo "🌐 STEP 5: CloudFront & OAC"
echo "============================================"

# 1. DÜZELTME: Windows için Python komutunu sabitliyoruz
PYTHON_CMD="python"

# OAC Oluşturma
OAC_ID=$(aws cloudfront create-origin-access-control \
    --origin-access-control-config '{"Name": "pptx-oac-'$BUCKET_NAME'", "Description": "PPTX OAC", "SigningProtocol": "sigv4", "SigningBehavior": "always", "OriginAccessControlOriginType": "s3"}' \
    --query 'OriginAccessControl.Id' \
    --output text \
    --region "$REGION")

echo "✅ OAC Created: $OAC_ID"

# CloudFront Config JSON
DIST_CONFIG='{
    "CallerReference": "pptx-'$BUCKET_NAME'",
    "Comment": "PPTX Converter",
    "DefaultRootObject": "index.html",
    "Origins": { "Quantity": 1, "Items": [ { "Id": "S3Origin", "DomainName": "'$BUCKET_NAME'.s3.'$REGION'.amazonaws.com", "S3OriginConfig": { "OriginAccessIdentity": "" }, "OriginAccessControlId": "'$OAC_ID'" } ] },
    "DefaultCacheBehavior": { "TargetOriginId": "S3Origin", "ViewerProtocolPolicy": "redirect-to-https", "AllowedMethods": { "Quantity": 2, "Items": ["GET", "HEAD"], "CachedMethods": { "Quantity": 2, "Items": ["GET", "HEAD"] } }, "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6", "Compress": true },
    "Enabled": true
}'

# Config'i dosyaya yaz (Windows'ta tırnak işaretleri karışmasın diye)
echo "$DIST_CONFIG" > dist_config.json

echo "⏳ Creating CloudFront Distribution (This may take a few moments)..."
DIST_RESULT=$(aws cloudfront create-distribution --distribution-config file://dist_config.json --region "$REGION" --output json)
rm dist_config.json

# 2. DÜZELTME: $PYTHON_CMD değişkenini kullanarak parse ediyoruz
DISTRIBUTION_ID=$(echo "$DIST_RESULT" | $PYTHON_CMD -c "import sys, json; print(json.load(sys.stdin)['Distribution']['Id'])")
DISTRIBUTION_DOMAIN=$(echo "$DIST_RESULT" | $PYTHON_CMD -c "import sys, json; print(json.load(sys.stdin)['Distribution']['DomainName'])")

echo "✅ Distribution Created: $DISTRIBUTION_ID ($DISTRIBUTION_DOMAIN)"

# Bucket Policy Güncelleme
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 3. DÜZELTME: Policy JSON'ını doğrudan komuta yazmak yerine dosyaya yazıyoruz.
# Windows terminalinde iç içe tırnak işaretleri (quote escaping) sorun yaratır.
cat <<EOF > bucket_policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCF",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudfront::${AWS_ACCOUNT_ID}:distribution/${DISTRIBUTION_ID}"
                }
            }
        }
    ]
}
EOF

echo "🔒 Updating Bucket Policy..."
aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file://bucket_policy.json --region "$REGION"
rm bucket_policy.json

echo "✅ Bucket Policy Updated!"

# ============================================================================
# STEP 6: LAMBDA DEPLOY
# ============================================================================

# ============================================================================
# STEP 6: LAMBDA DEPLOY
# ============================================================================

echo ""
echo "============================================"
echo "⚡ STEP 6: Deploying Lambdas"
echo "============================================"

# Helper function (Mevcut fonksiyonun kalsın, değişiklik yapmana gerek yok)
deploy_lambda() {
    local func_name=$1
    local file_name=$2
    local memory=$3
    local timeout=$4
    local layers=$5
    
    echo "📦 Deploying $func_name..."
    local dir=$(mktemp -d)
    cp "$file_name" "$dir/lambda_function.py"
    cd "$dir"
    zip -r9 func.zip lambda_function.py > /dev/null
    
    # Not: Burada sadece BUCKET_NAME var, aşağıda DISTRIBUTION_ID ekleyeceğiz
    local cmd="aws lambda create-function --function-name $func_name --runtime $LAMBDA_RUNTIME --role $ROLE_ARN --handler lambda_function.lambda_handler --zip-file fileb://func.zip --timeout $timeout --memory-size $memory --environment Variables={BUCKET_NAME=$BUCKET_NAME} --region $REGION --tags $TAGS"
    
    if [ -n "$layers" ]; then
        cmd="$cmd --layers $layers"
    fi
    
    $cmd > /dev/null
    cd - > /dev/null
    rm -rf "$dir"
}

# 1. Converter'ı normal şekilde kur
deploy_lambda "$CONVERTER_FUNCTION" "converter_lambda.py" "$CONVERTER_MEMORY" "$LAMBDA_TIMEOUT" "$LAYER_VERSION_ARN"

# 2. Dashboard'u kur
deploy_lambda "$DASHBOARD_FUNCTION" "dashboard_lambda.py" "$DASHBOARD_MEMORY" 60 ""

echo "⏳ Waiting for Dashboard Lambda to become active (this fixes the Pending error)..."
aws lambda wait function-active --function-name "$DASHBOARD_FUNCTION" --region "$REGION"

# 3. ÖNEMLİ: Dashboard fonksiyonuna DISTRIBUTION_ID yeteneğini ver
echo "⚙️ Configuring Dashboard Lambda Environment..."
aws lambda update-function-configuration \
    --function-name "$DASHBOARD_FUNCTION" \
    --environment "Variables={BUCKET_NAME=$BUCKET_NAME,DISTRIBUTION_ID=$DISTRIBUTION_ID}" \
    --region "$REGION" > /dev/null

echo "✅ Dashboard Lambda is now linked to CloudFront Distribution: $DISTRIBUTION_ID"

# ============================================================================
# STEP 7: TRIGGERS
# ============================================================================

echo ""
echo "============================================"
echo "🔔 STEP 7: S3 Triggers"
echo "============================================"

CONVERTER_ARN=$(aws lambda get-function --function-name "$CONVERTER_FUNCTION" --query 'Configuration.FunctionArn' --output text --region "$REGION")
DASHBOARD_ARN=$(aws lambda get-function --function-name "$DASHBOARD_FUNCTION" --query 'Configuration.FunctionArn' --output text --region "$REGION")

aws lambda add-permission --function-name "$CONVERTER_FUNCTION" --statement-id "S3Invoke" --action "lambda:InvokeFunction" --principal "s3.amazonaws.com" --source-arn "arn:aws:s3:::$BUCKET_NAME" --region "$REGION"
aws lambda add-permission --function-name "$DASHBOARD_FUNCTION" --statement-id "S3Invoke" --action "lambda:InvokeFunction" --principal "s3.amazonaws.com" --source-arn "arn:aws:s3:::$BUCKET_NAME" --region "$REGION"

NOTIF_CONFIG='{
    "LambdaFunctionConfigurations": [
        { "Id": "Converter", "LambdaFunctionArn": "'"$CONVERTER_ARN"'", "Events": ["s3:ObjectCreated:*"], "Filter": { "Key": { "FilterRules": [ { "Name": "prefix", "Value": "pptxs/" }, { "Name": "suffix", "Value": ".pptx" } ] } } },
        { "Id": "Dashboard", "LambdaFunctionArn": "'"$DASHBOARD_ARN"'", "Events": ["s3:ObjectCreated:*"], "Filter": { "Key": { "FilterRules": [ { "Name": "prefix", "Value": "metadata/" }, { "Name": "suffix", "Value": ".json" } ] } } }
    ]
}'

aws s3api put-bucket-notification-configuration --bucket "$BUCKET_NAME" --notification-configuration "$NOTIF_CONFIG" --region "$REGION"

# ============================================================================
# STEP 8: DASHBOARD INIT
# ============================================================================

echo "Creating initial dashboard..."
echo '<html><body><h1>Checking...</h1></body></html>' > index.html
aws s3 cp index.html "s3://$BUCKET_NAME/index.html" --content-type "text/html" --region "$REGION"
rm index.html



# ============================================================================
# FINISH
# ============================================================================

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "   Bucket: $BUCKET_NAME"
echo "   URL:    https://$DISTRIBUTION_DOMAIN"

# Save config
echo "BUCKET_NAME=$BUCKET_NAME" > .deploy-config
echo "DISTRIBUTION_ID=$DISTRIBUTION_ID" >> .deploy-config
echo "OAC_ID=$OAC_ID" >> .deploy-config
echo "CONVERTER_FUNCTION=$CONVERTER_FUNCTION" >> .deploy-config
echo "DASHBOARD_FUNCTION=$DASHBOARD_FUNCTION" >> .deploy-config
echo "LAYER_NAME=$LAYER_NAME" >> .deploy-config
echo "ROLE_NAME=$ROLE_NAME" >> .deploy-config
echo "CODEARTIFACT_DOMAIN=$CODEARTIFACT_DOMAIN" >> .deploy-config
echo "CODEARTIFACT_REPO=$CODEARTIFACT_REPO" >> .deploy-config
echo "REGION=$REGION" >> .deploy-config