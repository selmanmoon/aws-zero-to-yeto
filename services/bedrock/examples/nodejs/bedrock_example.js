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
