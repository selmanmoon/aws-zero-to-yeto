#!/bin/bash

# AWS ZERO to YETO - Bedrock Deployment Script (Direct AWS CLI)
# Bu script Bedrock örneklerini deploy etmek için kullanılır

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
PROJECT_NAME="aws-zero-to-yeto"
REGION="us-east-1"  # Bedrock sadece us-east-1'de mevcut

print_info "Bedrock Deployment başlatılıyor (Direct AWS CLI)..."
print_info "Proje: $PROJECT_NAME"
print_info "Bölge: $REGION"

# AWS CLI kontrolü
check_aws_cli

# Klasör yapısı oluştur
print_info "Klasör yapısı oluşturuluyor..."
mkdir -p examples/python
mkdir -p examples/nodejs

# Python örneği oluştur
print_info "Python Bedrock örneği oluşturuluyor..."
cat > examples/python/bedrock_example.py << 'EOF'
#!/usr/bin/env python3
"""
AWS ZERO to YETO - Bedrock Örnek Uygulaması
Bu script Amazon Bedrock API'sini Python ile kullanmayı gösterir.
"""

import json
import boto3
from botocore.exceptions import ClientError
import logging

# Logging yapılandırması
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class BedrockManager:
    def __init__(self, region='us-east-1'):
        """
        Bedrock client'ını başlat
        """
        self.region = region
        try:
            self.bedrock_client = boto3.client('bedrock', region_name=region)
            self.bedrock_runtime = boto3.client('bedrock-runtime', region_name=region)
            logger.info(f"Bedrock client başlatıldı - Bölge: {region}")
        except Exception as e:
            logger.error(f"Bedrock client başlatılamadı: {e}")
            raise

    def list_foundation_models(self):
        """
        Mevcut foundation model'leri listele
        """
        try:
            response = self.bedrock_client.list_foundation_models()
            models = response['modelSummaries']
            
            print(f"\n📋 Toplam {len(models)} foundation model mevcut:")
            print("-" * 60)
            
            for model in models:
                print(f"🤖 Model ID: {model['modelId']}")
                print(f"   Sağlayıcı: {model['providerName']}")
                print(f"   İsim: {model['modelName']}")
                print(f"   Giriş: {', '.join(model.get('inputModalities', []))}")
                print(f"   Çıkış: {', '.join(model.get('outputModalities', []))}")
                print("-" * 60)
                
            return models
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'AccessDeniedException':
                logger.error("Bedrock erişim reddedildi. Model erişim izni gerekebilir.")
                print("\n❌ Bedrock erişim hatası!")
                print("💡 Çözüm: AWS Console > Amazon Bedrock > Model access > Request model access")
            else:
                logger.error(f"Model listesi alınamadı: {e}")
            return []

    def test_claude_model(self, prompt="Merhaba, nasılsın?"):
        """
        Claude model ile test
        """
        try:
            model_id = 'anthropic.claude-v2'
            
            request_body = {
                "prompt": f"\n\nHuman: {prompt}\n\nAssistant:",
                "max_tokens_to_sample": 300,
                "temperature": 0.7,
                "top_p": 1,
            }
            
            print(f"\n🤖 Claude ile konuşma:")
            print(f"📝 Sorgu: {prompt}")
            print("⏳ Yanıt bekleniyor...")
            
            response = self.bedrock_runtime.invoke_model(
                body=json.dumps(request_body),
                modelId=model_id,
                accept='application/json',
                contentType='application/json'
            )
            
            response_body = json.loads(response['body'].read())
            completion = response_body.get('completion', '')
            
            print(f"💬 Claude: {completion.strip()}")
            
            return completion
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'AccessDeniedException':
                logger.error("Claude modeline erişim reddedildi.")
                print("\n❌ Claude model erişim hatası!")
                print("💡 Çözüm: AWS Console > Amazon Bedrock > Model access > anthropic.claude-v2")
            else:
                logger.error(f"Claude testi başarısız: {e}")
            return None

def main():
    """
    Ana fonksiyon
    """
    print("🚀 AWS ZERO to YETO - Bedrock Demo")
    print("=" * 50)
    
    try:
        # Bedrock manager oluştur
        bedrock = BedrockManager()
        
        # Model'leri listele
        models = bedrock.list_foundation_models()
        
        if models:
            # Claude ile test
            bedrock.test_claude_model("Python ile neler yapabilirim?")
        else:
            print("\n⚠️  Model erişimi yok, sadece API bağlantısı test edildi.")
            
    except Exception as e:
        logger.error(f"Demo başarısız: {e}")
        print(f"\n❌ Hata: {e}")
        
    print("\n✅ Demo tamamlandı!")

if __name__ == "__main__":
    main()
EOF

# Python requirements dosyası
cat > examples/python/requirements.txt << 'EOF'
boto3>=1.26.0
botocore>=1.29.0
EOF

# Node.js örneği oluştur
print_info "Node.js Bedrock örneği oluşturuluyor..."
cat > examples/nodejs/bedrock_example.js << 'EOF'
/**
 * AWS ZERO to YETO - Bedrock Örnek Uygulaması (Node.js)
 * Bu script Amazon Bedrock API'sini Node.js ile kullanmayı gösterir.
 */

const { BedrockClient, ListFoundationModelsCommand } = require('@aws-sdk/client-bedrock');
const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');

class BedrockManager {
    constructor(region = 'us-east-1') {
        this.region = region;
        this.bedrockClient = new BedrockClient({ region });
        this.bedrockRuntime = new BedrockRuntimeClient({ region });
        
        console.log(`🚀 Bedrock client başlatıldı - Bölge: ${region}`);
    }

    async listFoundationModels() {
        try {
            const command = new ListFoundationModelsCommand({});
            const response = await this.bedrockClient.send(command);
            const models = response.modelSummaries;

            console.log(`\n📋 Toplam ${models.length} foundation model mevcut:`);
            console.log('-'.repeat(60));

            models.forEach(model => {
                console.log(`🤖 Model ID: ${model.modelId}`);
                console.log(`   Sağlayıcı: ${model.providerName}`);
                console.log(`   İsim: ${model.modelName}`);
                console.log(`   Giriş: ${model.inputModalities?.join(', ') || 'N/A'}`);
                console.log(`   Çıkış: ${model.outputModalities?.join(', ') || 'N/A'}`);
                console.log('-'.repeat(60));
            });

            return models;

        } catch (error) {
            if (error.name === 'AccessDeniedException') {
                console.error('❌ Bedrock erişim reddedildi. Model erişim izni gerekebilir.');
                console.log('💡 Çözüm: AWS Console > Amazon Bedrock > Model access > Request model access');
            } else {
                console.error('Model listesi alınamadı:', error.message);
            }
            return [];
        }
    }

    async testClaudeModel(prompt = 'Merhaba, nasılsın?') {
        try {
            const modelId = 'anthropic.claude-v2';
            
            const requestBody = {
                prompt: `\n\nHuman: ${prompt}\n\nAssistant:`,
                max_tokens_to_sample: 300,
                temperature: 0.7,
                top_p: 1
            };

            console.log(`\n🤖 Claude ile konuşma:`);
            console.log(`📝 Sorgu: ${prompt}`);
            console.log('⏳ Yanıt bekleniyor...');

            const command = new InvokeModelCommand({
                body: JSON.stringify(requestBody),
                modelId: modelId,
                accept: 'application/json',
                contentType: 'application/json'
            });

            const response = await this.bedrockRuntime.send(command);
            const responseBody = JSON.parse(Buffer.from(response.body).toString());
            const completion = responseBody.completion || '';

            console.log(`💬 Claude: ${completion.trim()}`);

            return completion;

        } catch (error) {
            if (error.name === 'AccessDeniedException') {
                console.error('❌ Claude modeline erişim reddedildi.');
                console.log('💡 Çözüm: AWS Console > Amazon Bedrock > Model access > anthropic.claude-v2');
            } else {
                console.error('Claude testi başarısız:', error.message);
            }
            return null;
        }
    }
}

async function main() {
    console.log('🚀 AWS ZERO to YETO - Bedrock Demo (Node.js)');
    console.log('='.repeat(50));

    try {
        // Bedrock manager oluştur
        const bedrock = new BedrockManager();

        // Model'leri listele
        const models = await bedrock.listFoundationModels();

        if (models.length > 0) {
            // Claude ile test
            await bedrock.testClaudeModel('Node.js ile neler yapabilirim?');
        } else {
            console.log('\n⚠️  Model erişimi yok, sadece API bağlantısı test edildi.');
        }

    } catch (error) {
        console.error('Demo başarısız:', error.message);
        console.log(`\n❌ Hata: ${error.message}`);
    }

    console.log('\n✅ Demo tamamlandı!');
}

// Script direkt çalıştırılırsa main fonksiyonunu çağır
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { BedrockManager };
EOF

# Node.js package.json dosyası
cat > examples/nodejs/package.json << 'EOF'
{
  "name": "aws-zero-to-yeto-bedrock",
  "version": "1.0.0",
  "description": "AWS ZERO to YETO - Bedrock Örnek Uygulaması",
  "main": "bedrock_example.js",
  "scripts": {
    "start": "node bedrock_example.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "@aws-sdk/client-bedrock": "^3.400.0",
    "@aws-sdk/client-bedrock-runtime": "^3.400.0"
  },
  "keywords": [
    "aws",
    "bedrock",
    "ai",
    "machine-learning"
  ],
  "author": "AWS ZERO to YETO",
  "license": "MIT"
}
EOF

# Bedrock servisini test et (Direct AWS CLI)
print_info "Bedrock servisini test ediliyor..."

# Test: Bedrock model'lerini listele
print_info "Bedrock model'leri listeleniyor..."
aws bedrock list-foundation-models --region $REGION --output table 2>/dev/null || {
    print_warning "Bedrock model'lerine erişim yok. Model erişim izni gerekebilir."
}

# Direct AWS CLI kullanımı - doğrudan test yapıyoruz
cat > test-bedrock.py << 'EOF'
#!/usr/bin/env python3
import boto3
import json

def test_bedrock():
    try:
        bedrock = boto3.client('bedrock', region_name='us-east-1')
        models = bedrock.list_foundation_models()
        print("✅ Bedrock'e erişim başarılı!")
        print(f"Toplam model sayısı: {len(models['modelSummaries'])}")
        return True
    except Exception as e:
        print(f"❌ Bedrock erişim hatası: {str(e)}")
        return False

if __name__ == "__main__":
    test_bedrock()
EOF

python3 test-bedrock.py 2>/dev/null || {
    print_warning "Python Bedrock testi başarısız. Boto3 kurulu olmalı."
}

# Cleanup test file
rm -f test-bedrock.py

# Sadece örnekler oluşturuluyor
print_info "Direct AWS CLI kullanılıyor."

# Deployment bilgilerini kaydet

print_success "🎉 Bedrock deployment tamamlandı (Direct AWS CLI)!"
print_info "Proje: $PROJECT_NAME"
print_info "Bölge: $REGION"
print_info "📝 Deployment bilgileri README'de mevcut"

print_warning "⚠️  Bedrock sadece us-east-1 bölgesinde mevcut"
print_warning "⚠️  Foundation model'lere erişim için AWS hesabınızda onay gerekebilir"

echo ""
print_info "Test komutları:"
echo "  cd examples/python && python3 bedrock_example.py"
echo "  cd examples/nodejs && npm install && npm start"
echo "  aws bedrock list-foundation-models --region us-east-1"