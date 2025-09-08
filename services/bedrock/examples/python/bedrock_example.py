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
