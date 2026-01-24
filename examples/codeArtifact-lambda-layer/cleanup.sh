#!/bin/bash

# ============================================================================
# PPTX to PDF Converter - Cleanup Script (ULTIMATE EDITION)
# ============================================================================

# Hata olduğunda durma, temizlik yapıyoruz.
set +e 

echo "🧹 PPTX Cleanup Initializing..."
echo "============================================"

# ----------------------------------------------------------------------------
# 1. ROBUST PYTHON DETECTION
# ----------------------------------------------------------------------------
PYTHON_CMD=""
if command -v python &> /dev/null && python --version &> /dev/null; then
    PYTHON_CMD="python"
elif command -v python3 &> /dev/null && python3 --version &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v py &> /dev/null && py --version &> /dev/null; then
    PYTHON_CMD="py"
fi

if [ -z "$PYTHON_CMD" ]; then
    echo "❌ Hata: Çalışan bir Python (python, python3 veya py) bulunamadı."
    exit 1
fi
echo "✅ Using Python: $PYTHON_CMD ($($PYTHON_CMD --version))"

# ----------------------------------------------------------------------------
# 2. LOAD CONFIG
# ----------------------------------------------------------------------------
if [ -f ".deploy-config" ]; then
    source .deploy-config
else
    echo "❌ .deploy-config not found. Please verify variables manually."
    exit 1
fi

echo "   Region:   $REGION"
echo "   Bucket:   $BUCKET_NAME"
echo "   Dist ID:  $DISTRIBUTION_ID"
echo "   Role:     $ROLE_NAME"

echo ""
read -p "⚠️  DELETE ALL RESOURCES? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then exit 0; fi
echo ""

# ============================================================================
# 3. S3 BUCKET
# ============================================================================
echo "🪣 Cleaning S3 Bucket..."
aws s3 rb "s3://$BUCKET_NAME" --force --region "$REGION" 2>/dev/null || echo "   ⚠️ Bucket already deleted."

# ============================================================================
# 4. CLOUDFRONT (Dosya Tabanlı & Güvenli)
# ============================================================================
echo "🌐 Checking CloudFront..."

if [ -n "$DISTRIBUTION_ID" ]; then
    DIST_STATUS=$(aws cloudfront get-distribution --id "$DISTRIBUTION_ID" --region "$REGION" --query "Distribution.Status" --output text 2>/dev/null)

    if [ -z "$DIST_STATUS" ]; then
        echo "   ⚠️ Distribution not found, skipping..."
    else
        echo "   Target Distribution: $DISTRIBUTION_ID"
        
        aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID" --region "$REGION" > cf_config.json

        IS_ENABLED=$($PYTHON_CMD -c "import sys, json; print(json.load(open('cf_config.json'))['DistributionConfig']['Enabled'])")
        ETAG=$($PYTHON_CMD -c "import sys, json; print(json.load(open('cf_config.json'))['ETag'])")

        if [ "$IS_ENABLED" == "True" ]; then
            echo "   🔻 Disabling Distribution (Waiting for AWS)..."
            
            $PYTHON_CMD -c "
import json
with open('cf_config.json', 'r') as f:
    data = json.load(f)
cfg = data['DistributionConfig']
cfg['Enabled'] = False
print(json.dumps(cfg))" > cf_disabled.json

            aws cloudfront update-distribution \
                --id "$DISTRIBUTION_ID" \
                --distribution-config file://cf_disabled.json \
                --if-match "$ETAG" \
                --region "$REGION" > /dev/null

            echo "   ⏳ Waiting for deployment (bu işlem birkaç dakika sürer)..."
            aws cloudfront wait distribution-deployed --id "$DISTRIBUTION_ID" --region "$REGION"
            
            aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID" --region "$REGION" > cf_final.json
            ETAG=$($PYTHON_CMD -c "import sys, json; print(json.load(open('cf_final.json'))['ETag'])")
        else
            echo "   ℹ️ Distribution is already disabled."
        fi

        echo "   🗑️ Deleting Distribution..."
        aws cloudfront delete-distribution --id "$DISTRIBUTION_ID" --if-match "$ETAG" --region "$REGION"
        
        rm -f cf_config.json cf_disabled.json cf_final.json
    fi
fi

if [ -n "$OAC_ID" ]; then
    echo "   🗑️ Deleting Origin Access Control..."
    ETAG_OAC=$(aws cloudfront get-origin-access-control --id "$OAC_ID" --region "$REGION" --query "ETag" --output text 2>/dev/null)
    if [ -n "$ETAG_OAC" ]; then
        aws cloudfront delete-origin-access-control --id "$OAC_ID" --if-match "$ETAG_OAC" --region "$REGION"
    fi
fi

# ============================================================================
# 5. LAMBDA & LOGS
# ============================================================================
echo "⚡ Deleting Lambdas..."
aws lambda delete-function --function-name "$CONVERTER_FUNCTION" --region "$REGION" 2>/dev/null || echo "   - Converter function missing"
aws lambda delete-function --function-name "$DASHBOARD_FUNCTION" --region "$REGION" 2>/dev/null || echo "   - Dashboard function missing"

echo "📜 Deleting CloudWatch Logs..."
aws logs delete-log-group --log-group-name "/aws/lambda/$CONVERTER_FUNCTION" --region "$REGION" 2>/dev/null || true
aws logs delete-log-group --log-group-name "/aws/lambda/$DASHBOARD_FUNCTION" --region "$REGION" 2>/dev/null || true

# ============================================================================
# 6. LAYERS
# ============================================================================
echo "📚 Deleting Layers..."
VERSIONS=$(aws lambda list-layer-versions --layer-name "$LAYER_NAME" --region "$REGION" --query 'LayerVersions[].Version' --output text 2>/dev/null)
if [ -n "$VERSIONS" ]; then
    for v in $VERSIONS; do
        echo "   - Deleting layer version $v..."
        aws lambda delete-layer-version --layer-name "$LAYER_NAME" --version-number "$v" --region "$REGION"
    done
fi

# ============================================================================
# 7. IAM ROLE
# ============================================================================
echo "🔐 Deleting IAM Role & Policies..."
aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "S3AccessPolicy" --region "$REGION" 2>/dev/null || true
aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "CFInvalidationPolicy" --region "$REGION" 2>/dev/null || true
aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" --region "$REGION" 2>/dev/null || true
aws iam delete-role --role-name "$ROLE_NAME" --region "$REGION" 2>/dev/null || echo "   ⚠️ Role already deleted."

# ============================================================================
# 8. CODEARTIFACT
# ============================================================================
echo "📦 Deleting CodeArtifact..."
aws codeartifact delete-repository --domain "$CODEARTIFACT_DOMAIN" --repository "$CODEARTIFACT_REPO" --region "$REGION" 2>/dev/null || true
aws codeartifact delete-domain --domain "$CODEARTIFACT_DOMAIN" --region "$REGION" 2>/dev/null || true

# ============================================================================
# FINISH
# ============================================================================
rm -f .deploy-config
echo "✅ Cleanup Complete! All resources (including Logs) are gone."