# Amazon Bedrock

## 📖 Servis Hakkında

Amazon Bedrock, AWS'nin tam yönetilen generative AI servisidir. En iyi foundation model'leri (Claude, Llama, Mistral, vb.) tek bir API üzerinden kullanmanızı sağlar.

### 🎯 Bedrock'ın Temel Özellikleri

- **Foundation Models**: Claude, Llama, Mistral, Cohere, Stability AI
- **Serverless**: Sunucu yönetimi yok
- **Pay-per-use**: Sadece kullandığınız kadar ödeme
- **Enterprise Security**: AWS güvenlik standartları
- **Fine-tuning**: Model özelleştirme
- **Knowledge Bases**: Özel bilgi tabanları

### 🏗️ Bedrock Mimarisi

```
Foundation Models (Temel Modeller)
    ↓
Bedrock API (API Katmanı)
    ↓
Your Application (Uygulamanız)
    ↓
Knowledge Bases (Bilgi Tabanları)
```

## 🤖 Desteklenen Foundation Models

### 1. Anthropic Claude
- **Claude 3 Sonnet**: Genel amaçlı, hızlı
- **Claude 3 Haiku**: En hızlı, maliyet etkin
- **Claude 3 Opus**: En gelişmiş, karmaşık görevler
- **Claude Instant**: Hızlı yanıtlar için

### 2. Meta Llama
- **Llama 2**: Açık kaynak, çok dilli
- **Llama 2 Chat**: Sohbet odaklı
- **Llama 2 Code**: Kod yazma ve analiz

### 3. Mistral AI
- **Mistral 7B**: Hafif ve hızlı
- **Mixtral 8x7B**: Gelişmiş performans

### 4. Cohere
- **Command**: İngilizce odaklı
- **Command Light**: Hızlı ve maliyet etkin

### 5. Stability AI
- **Stable Diffusion XL**: Görüntü üretimi
- **Stable Diffusion 2.1**: Görüntü üretimi

## 💰 Maliyet Hesaplama

### Fiyatlandırma Modeli
- **Input tokens**: Giriş metni için ücret
- **Output tokens**: Çıkış metni için ücret
- **Model bazlı**: Her model farklı fiyat

### Örnek Hesaplama (Claude 3 Sonnet)
```
Input: 1000 token × $0.003/1K tokens = $0.003
Output: 500 token × $0.015/1K tokens = $0.0075
Toplam: $0.0105/istek
```

## 🚀 Bedrock API Kullanımı

### Python SDK ile Temel Kullanım
```python
import boto3
import json

# Bedrock client oluştur
bedrock = boto3.client(
    service_name='bedrock-runtime',
    region_name='us-east-1'
)

def generate_text(prompt, model_id='anthropic.claude-3-sonnet-20240229-v1:0'):
    """
    Bedrock ile metin üretimi
    """
    # Request body hazırla
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1000,
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ]
    })
    
    # API çağrısı yap
    response = bedrock.invoke_model(
        body=body,
        modelId=model_id,
        accept='application/json',
        contentType='application/json'
    )
    
    # Yanıtı işle
    response_body = json.loads(response.get('body').read())
    return response_body['content'][0]['text']

# Kullanım örneği
response = generate_text("Merhaba! AWS Bedrock hakkında bilgi verir misin?")
print(response)
```

### Streaming Response
```python
def generate_text_streaming(prompt, model_id='anthropic.claude-3-sonnet-20240229-v1:0'):
    """
    Streaming yanıt ile metin üretimi
    """
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1000,
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ]
    })
    
    response = bedrock.invoke_model_with_response_stream(
        body=body,
        modelId=model_id,
        accept='application/json',
        contentType='application/json'
    )
    
    for event in response.get('body'):
        chunk = json.loads(event['chunk']['bytes'].decode())
        if chunk['type'] == 'content_block_delta':
            yield chunk['delta']['text']

# Streaming kullanımı
for text_chunk in generate_text_streaming("Uzun bir hikaye anlat"):
    print(text_chunk, end='', flush=True)
```

## 🔧 Knowledge Bases (Bilgi Tabanları)

### Knowledge Base Oluşturma
```python
import boto3

bedrock_agent = boto3.client('bedrock-agent-runtime')

def create_knowledge_base(name, description, data_source):
    """
    Knowledge base oluşturur
    """
    response = bedrock_agent.create_knowledge_base(
        name=name,
        description=description,
        knowledgeBaseConfiguration={
            'type': 'VECTOR',
            'vectorKnowledgeBaseConfiguration': {
                'embeddingModelArn': 'arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1'
            }
        },
        dataSource={
            'type': 'S3',
            'dataSourceConfiguration': {
                's3Configuration': {
                    'bucketArn': data_source['bucket_arn'],
                    'inclusionPrefixes': data_source['prefixes']
                }
            }
        }
    )
    return response['knowledgeBase']['knowledgeBaseId']

# Kullanım
kb_id = create_knowledge_base(
    name="Şirket Bilgileri",
    description="Şirket dokümanları ve politikaları",
    data_source={
        'bucket_arn': 'arn:aws:s3:::my-company-docs',
        'prefixes': ['policies/', 'handbooks/']
    }
)
```

### Knowledge Base ile Sorgulama
```python
def query_knowledge_base(query, knowledge_base_id):
    """
    Knowledge base'den bilgi sorgular
    """
    response = bedrock_agent.retrieve(
        knowledgeBaseId=knowledge_base_id,
        retrievalQuery={
            'text': query
        },
        retrievalConfiguration={
            'vectorSearchConfiguration': {
                'numberOfResults': 5
            }
        }
    )
    
    return response['retrievalResults']

# Kullanım
results = query_knowledge_base("Şirket izin politikası nedir?", kb_id)
for result in results:
    print(f"İçerik: {result['content']['text']}")
    print(f"Kaynak: {result['location']['s3Location']['uri']}")
```

## 🎨 Görüntü Üretimi (Stable Diffusion)

### Görüntü Üretimi
```python
import base64
import io
from PIL import Image

def generate_image(prompt, model_id='stability.stable-diffusion-xl-v1'):
    """
    Stable Diffusion ile görüntü üretimi
    """
    body = json.dumps({
        "text_prompts": [
            {
                "text": prompt,
                "weight": 1
            }
        ],
        "cfg_scale": 10,
        "steps": 50,
        "seed": 0
    })
    
    response = bedrock.invoke_model(
        body=body,
        modelId=model_id,
        accept='application/json',
        contentType='application/json'
    )
    
    response_body = json.loads(response.get('body').read())
    
    # Base64'ten görüntüye çevir
    image_data = base64.b64decode(response_body['artifacts'][0]['base64'])
    image = Image.open(io.BytesIO(image_data))
    
    return image

# Kullanım
image = generate_image("Güzel bir Türk manzarası, güneş batımında")
image.save("turkish_landscape.png")
```

## 🔐 Güvenlik ve İzinler

### IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream"
            ],
            "Resource": [
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
                "arn:aws:bedrock:us-east-1::foundation-model/meta.llama2-70b-chat-v1",
                "arn:aws:bedrock:us-east-1::foundation-model/stability.stable-diffusion-xl-v1"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:CreateKnowledgeBase",
                "bedrock:Retrieve",
                "bedrock:Query"
            ],
            "Resource": "*"
        }
    ]
}
```

## 🧪 Test Senaryoları

Bu klasörde bulunan örnekler ile test edebileceğiniz senaryolar:

1. **Temel Metin Üretimi**
   - Basit prompt-response
   - Streaming yanıtlar
   - Farklı modeller karşılaştırması

2. **Sohbet Uygulaması**
   - Conversation history
   - Context management
   - Multi-turn dialogs

3. **Kod Yardımcısı**
   - Kod yazma
   - Kod analizi
   - Debugging yardımı

4. **İçerik Üretimi**
   - Blog yazısı yazma
   - Sosyal medya içeriği
   - E-posta taslakları

5. **Görüntü Üretimi**
   - Prompt engineering
   - Görüntü varyasyonları
   - Style transfer

6. **Knowledge Base Entegrasyonu**
   - Doküman yükleme
   - Bilgi sorgulama
   - RAG (Retrieval-Augmented Generation)

## 📚 Öğrenme Kaynakları

- [Amazon Bedrock Dokümantasyonu](https://docs.aws.amazon.com/bedrock/)
- [Bedrock Examples](https://github.com/aws-samples/amazon-bedrock-workshop)
- [Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)

## 🎯 Sonraki Adımlar

Bedrock'ı öğrendikten sonra şu servisleri keşfedin:
- **Amazon SageMaker** - Custom model eğitimi
- **AWS Glue** - Veri hazırlama ve ETL
- **Amazon OpenSearch** - Vector search
- **Amazon Kendra** - Intelligent search
