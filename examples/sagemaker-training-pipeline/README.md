# **AWS SageMaker ile MNIST Training - w/Docker**

Bu projede MNIST veri setini PyTorch framework kullanarak CNN modeliyle AWS SageMaker'da training işlemini yapacağız. Açıkcası buradaki MNIST datasetini eğitmek için en base bilgisayar dahil yeterli olacaktır ama buradaki benim amacım sistemi anlatmak ama isterseniz kapsamlı bir training örneği yapabiliriz. Mesela U-Net Modeli için bu sistemi deneyebiliriz.  

## **İki Yöntem**

Bu projeyi iki farklı şekilde çalıştırabilirsiniz:

1. **Otomatik Deployment (Önerilen):** `deploy.sh` ve `cleanup.sh` script'lerini kullanarak tek komutla tüm işlemleri yapabilirsiniz. → [Script Kullanımı](#script-ile-otomatik-deployment)

2. **Manuel Deployment:** Adım adım her komutu manuel olarak çalıştırabilirsiniz. → [Manuel Adımlar](#manuel-deployment-adımları)

## **Mimari**
```
Kullanıcı → S3 (Veri Upload) → SageMaker (Training) → S3 (Model Output)
                                      ↓
                                 ECR (Docker Image)
```

## Ön Bilgiler

**AWS Free Tier:** İlk 2 ay boyunca ml.m5.xlarge instance kullanılabilir. Açıkcası çok güçlü bir instance değil hatta hiç değil ama MNIST gibi küçük veri setleri için yeterli olacaktır. Maliyet oldukça düşük (~0.10 dolar civarı).

**Farklı Instance için:** Farklı bir instance kullanmak istediğinizde `Quota Increase Request`yapmanız gerekiyor. 

**Gereksinimler:**

## Kurulum
Buradaki komutlar macOS içindir.
```bash
# AWS CLI kurulumu
brew install awscli

# Docker kurulumu
brew install docker

# Login işlemleri
aws login
# aws configure de olabilir.
docker login
```

## 1. IAM Role Oluşturma

SageMaker için gerekli izinlere sahip bir IAM role oluşturun. **Üretim ortamı için** mümkün olduğunca dar kapsamlı (least‑privilege) özel bir IAM policy kullanmanız önerilir. Bu policy, yalnızca bu örnek için gereken izinleri içermelidir:
- İlgili S3 bucket/prefix için okuma/yazma (training verisini okuma, model çıktılarını yazma)
- Eğitim image’ının bulunduğu ECR repository’si için gerekli `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer` izinleri
- Sadece bu projede kullanacağınız training job, model ve endpoint isimlerini kapsayan `sagemaker:CreateTrainingJob`, `sagemaker:DescribeTrainingJob`, `sagemaker:CreateModel`, vb. gerekli SageMaker aksiyonları

> Not: Kolaylık olması için **sadece deneme / geliştirme ortamında**, geçici olarak geniş bir yönetilen policy (ör. `AmazonSageMakerFullAccess`) kullanılabilir. Ancak bu policy **üretim ortamında kullanılmamalı** ve daha sonra mutlaka daraltılmalıdır.
---

## Script ile Otomatik Deployment

Tüm işlemleri otomatik yapmak için iki script kullanılır:

### 1. Data Hazırlama 
 
```bash
./prepare-data.sh
```

Bu script:
- ✅ S3 bucket oluşturur
- ✅ MNIST verisini indirir
- ✅ Veriyi S3'e yükler
- ✅ Bilgileri `.data-info` dosyasına kaydeder

**Not:** Bu adım sadece **bir kere** yapılır. Birden fazla training job çalıştıracaksanız tekrar çalıştırmanıza gerek yok. O yüzden ayrı hazırladım. 

### 2. Model Training 

```bash
./deploy.sh
```

Bu script:
- ✅ `.data-info` dosyasından S3 bilgilerini okur
- ✅ IAM role kontrol eder
- ✅ ECR repository oluşturur
- ✅ Docker image build edip ECR'a push eder
- ✅ SageMaker training job başlatır
- ✅ Deployment bilgilerini `.deployment-info` dosyasına kaydeder

### 3. Temizlik

```bash
./cleanup.sh
```

Script `.deployment-info` ve `.data-info` dosyalarından bilgileri okuyarak:
- ✅ Çalışan training job'ları durdurur
- ✅ S3 bucket'ı ve içeriğini siler
- ✅ ECR repository'yi ve image'ları siler
- ✅ Lokal dosyaları temizler

### İş Akışı

```bash
# 1. Data hazırla (bir kere)
./prepare-data.sh

# 2. Training başlat (istediğiniz kadar)
./deploy.sh
./deploy.sh  # Farklı hyperparameter ile tekrar
./deploy.sh  # Başka bir model ile tekrar

# 3. Temizlik 
./cleanup.sh
```

### Örnek Kullanım

```bash
# İlk data hazırlığı
$ ./prepare-data.sh
Region: us-east-1
Bucket [mnist-training-20260103]: my-mnist-bucket
▶ Creating S3 bucket...
▶ Downloading and uploading MNIST data...
✓ Uploaded train_data.npy
✓ Uploaded train_labels.npy
✓ Uploaded test_data.npy
✓ Uploaded test_labels.npy
✓ Data prepared and uploaded to s3://my-mnist-bucket/mnist-data/
Next: ./deploy.sh

# Training başlat
$ ./deploy.sh
▶ Using existing data: s3://my-mnist-bucket/mnist-data/
SageMaker Role: MySageMakerRole
▶ Checking IAM role...
▶ Setting up ECR...
▶ Building and pushing Docker image...
▶ Starting training job...
✓ Deployed: mnist-training-job-20260103120000

Monitor: aws sagemaker describe-training-job --training-job-name mnist-training-job-20260103120000
Cleanup: ./cleanup.sh
```

---

## Manuel Deployment Adımları

Manuel olarak her adımı kontrol ederek ilerlemek istiyorsanız aşağıdaki adımları takip edin:

- S3 bucket'ınıza erişim izinleri

Mevcut SageMaker role'lerinizi kontrol etmek için:

```bash
aws iam list-roles --query "Roles[?contains(RoleName, 'SageMaker')].{Name:RoleName,Arn:Arn}" --output table
```

## 2. S3 Bucket Oluşturma

Evet tabi ki her şeyde oladuğu gibi S3 gerekiyor. Training verileri ve output için S3 bucket'ı oluşturun:

```bash
aws s3api create-bucket \
  --bucket mnist-training \
  --region <region> \
  --create-bucket-configuration LocationConstraint=<region>
```


## 3. MNIST Verisini S3'e Yükleme

Şimdi normalde training işlemlerinde bir dataset olur onda çalışırsınız ama bizde datasetimiz direkt PyTorch Framework'ten geleceğinden dolayı onu ayrıca localde çalıştırarak ilk bi dataseti oluşturup onu da S3 ye bucketımıza göndermemiz gerekiyor. Ki zaten bu method çok doğru bir yaklaşım training işlemlerinde training ve gerektiğinde testler hariç diğer işlemleri localde yani kendi bilgisayarınızda yapmanız daha doğru bir yaklaşım olur. Böylece daha tasarruflu sistem yapmış olursunuz. 

Nacizane tavsiyemde bu sistemlerde veya Colab te bile training yapsanız kodunuzu SOLID prensibine veya benzer bir prensib göre hazırlamanız. İsterseniz sizler için bunlara uygun bir örnekte yapabilirim. 

Evet lafı uzatmayayım, geri dönemlim şimdi Data-S3.py ye gerekli bilgiler girerek kodumuzu çalıştıralım. `bucket_name` 

Gerekli kütüphaneler 
```bash
pip install -r requirements.txt
```
`Data-S3.py` dosyası:
- MNIST verisini PyTorch ile indirir
- NumPy formatına çevirip normalize eder
- S3 bucket'ına yükler

Script'i çalıştırın:

```bash
python Data-S3.py
```

Verinin yüklediğini kontrol edelim:

```bash
aws s3 ls s3://<bucket-name>/mnist-data/
```

## 4. ECR Repository Oluşturma

Docker image'ınızı saklamak için ECR repository'si oluştuşturalım. Repository adını `sagemaker-mnist` belirlendim ancak siz değiştirebilirsiniz:

```bash
aws ecr create-repository \
  --repository-name sagemaker-mnist \
  --region <region>
```

Çıktıda gelen `repositoryUri` ve `repositoryArn` değerlerini not edin.

## 5. Docker Image Hazırlama

**Neden Docker?** SageMaker, training ortamını izole etmek ve reproducibility sağlamak için Docker container'ları kullanır. Bu sayede dependency'lerinizi tam kontrol edebilir ve herhangi bir ortamda aynı sonuçları elde edebilirsiniz.

### Dockerfile

Ben modeli PyTorch Framerwork ile yaptığımdan Docker Hub da PyTorch Tagini aldım. Değiştirmek isterseniz Hub'a bakmanızı öneririm ki her türlü bakın güncel olduğuna veya sizin train operasyonunuz farklı bir PyTorch versionu gerekiyordur Docker Hub'tan bulabilirisniz:

```dockerfile
FROM pytorch/pytorch:2.9.1-cuda12.6-cudnn9-runtime

WORKDIR /opt/ml/code

ENV DATA_DIR=/opt/ml/input/data/training
ENV OUTPUT_DIR=/opt/ml/model
RUN mkdir -p "$DATA_DIR" "$OUTPUT_DIR"

COPY train.py /opt/ml/code/train.py

ENV PYTHONUNBUFFERED=1
ENV SAGEMAKER_PROGRAM=train.py

ENTRYPOINT ["python", "train.py"]
```

### train.py

Training script şu klasik yapıyı takip etmeli:
- Veriyi `/opt/ml/input/data/training/` yolundan okur
- Model'i `/opt/ml/model/` yoluna kaydeder
- Training metriklerini stdout'a yazdırır

### Docker Build ve Push

**Önemli:** SageMaker instance'ları `linux/amd64` mimarisinde çalıştığı için platform belirtmek kritik önem taşır. <region>, <account-id> bilgilerini girmeyi unutmayın. 

```bash
# ECR'a login
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.<region>.amazonaws.com
```
`Login Succeeed` çıktısı almanız lazım. 
Burada docker i build etme normalde docker build etmek  `docker build -t <image-name>` ama burada önemli olacak kısım ECR'a uyumluluk. ECR sunucuları `linux/amd64` olduğu için onda dikkat etmeniz gerekiyor evet bilgide edindiğimize göre direkt build edip push edebiliriz.
```bash
# Build ve Push (tek komutta)
docker buildx build \
  --platform linux/amd64 \
  -t <account-id>.dkr.ecr.<region>.amazonaws.com/mnist-training:latest \
  --push \
  .
```

Push işleminin başarılı olduğunu doğrulayalım:

```bash
aws ecr describe-images \
  --repository-name mnist-training \
  --region <region>
```

## 6. SageMaker Training Job Başlatma

Evet gelelim en önemli kısma training kısmına burada bir çok veriye ihtiyaç var. Parametreler kısmındaki değişikliklere göre komutu düzenleyerek komutu çalıştıralım. 

```bash
aws sagemaker create-training-job \
  --training-job-name mnist-training-job-$(date +%Y%m%d%H%M%S) \
  --algorithm-specification TrainingImage=<account-id>.dkr.ecr.<region>.amazonaws.com/mnist-training:v1,TrainingInputMode=File \
  --role-arn arn:aws:iam::<account-id>:role/<sagemaker-role-name> \
  --input-data-config '[{"ChannelName":"training","DataSource":{"S3DataSource":{"S3DataType":"S3Prefix","S3Uri":"s3://<bucket-name>/mnist-data/","S3DataDistributionType":"FullyReplicated"}},"ContentType":"application/x-npy"}]' \
  --output-data-config S3OutputPath=s3://<bucket-name>/mnist-output \
  --resource-config InstanceType=ml.m5.xlarge,InstanceCount=1,VolumeSizeInGB=30 \
  --stopping-condition MaxRuntimeInSeconds=3600
```9. Temizlik

### Otomatik Temizlik (Önerilen)

```bash
./cleanup.sh
```

### Manuel Temizlik

İşlemler bitince kaynakları silin:

```bash
# Çalışan job'ları durdur (opsiyonel)
aws sagemaker stop-training-job --training-job-name <job-name>

# S3 bucket'ı temizle
aws s3 rm s3://<bucket-name> --recursive
aws s3api delete-bucket --bucket <bucket-name>

# ECR repository'yi sil
aws ecr delete-repository --repository-name mnist-training --force --region <region>

# Lokal dosyaları temizle
rm -rf ./data model.tar.gz
```

---

## Hangi Yöntemi Seçmeliyim?

| Özellik | Script (prepare + deploy) | Manuel |
|---------|--------------------------|--------|
| Hız | ⚡ Çok hızlı (5-10 dk) | 🐢 Yavaş (20-30 dk) |
| Hata riski | ✅ Düşük | ⚠️ Yüksek |
| Öğrenme | 📚 Temel | 📖 Detaylı |
| Esneklik | 🔧 Orta | 🎯 Yüksek |
| Tekrar Kullanım | ♻️ Data bir kere hazırla | 🔨 Her seferinde tekrar |
| Cleanup | 🧹 Otomatik | 🔨 Manuel |

**Tavsiye:** 
- İlk defa çalıştırıyorsanız veya hızlı test etmek istiyorsanız → **Script'leri kullanın** (`prepare-data.sh` + `deploy.sh`)
- Birden fazla training job çalıştıracaksanız → **Kesinlikle script'leri kullanın** (data hazırlığı bir kere yeter)
- Sistem'i detaylı öğrenmek istiyorsanız → **Manuel adımları** takip edin

---

## 7. Training İzleme

Genellikle aws sagemaker komutu çalıştıktan sonra ben de bir heyecan başlıyor. Belki de bu zaman kadar çok az training işlemi yaptığım için olabilir. O yüzden sadece terminalden kontrol yapmıyorum console'dan sürekli kontrol ediyorum. O yüzden hem console hem de terminalden sürekli kontrolleri sağlıyorum. 

### Console üzerinden

AWS Console > SageMaker > Training jobs bölümünden job'ın durumunu izleyebilirsiniz.

### Terminalden

```bash
# En son job'u listele
aws sagemaker list-training-jobs \
  --sort-by CreationTime \
  --sort-order Descending \
  --max-results 1

# Job detayı
aws sagemaker describe-training-job \
  --training-job-name <job-name>

# CloudWatch logları
aws logs tail /aws/sagemaker/TrainingJobs \
  --follow \
  --log-stream-names <job-name>/algo-1-xxxxx
```

## 8. Model Çıktısını İndirme

Training tamamlandıktan sonra model S3'te `model.tar.gz` olarak saklanır:

```bash
# Model output yolunu öğren
aws sagemaker describe-training-job \
  --training-job-name <job-name> \
  --query 'ModelArtifacts.S3ModelArtifacts'

# Model'i indir
aws s3 cp s3://<bucket-name>/mnist-output/<job-name>/output/model.tar.gz ./

# Aç
tar -xzf model.tar.gz
```

## Yaygın Hatalar ve Çözümler

### 1. "No S3 objects found" hatası
S3 bucket'ında veri olduğundan emin olun dediğim gibi kontrol iyidir takıntılı olunmadığı sürece:
```bash
aws s3 ls s3://<bucket-name>/mnist-data/
```

### 2. "Exec format error" hatası
Docker image'ı `--platform linux/amd64` ile build etmeyi unutmayın. 

### 3. IAM izin hataları
Role'ün S3 ve SageMaker izinlerine sahip olduğundan emin olun. Role'e `AmazonSageMakerFullAccess` policy'si ve S3 bucket'ınıza erişim izinleri ekleyin.

## Region Seçimi

Tüm işlemlerde aynı region'ı kullanın. Free tier ve fiyatlandırma için: https://aws.amazon.com/sagemaker/pricing/

## Temizlik

İşlemler bitince kaynakları silin:

```bash
# S3 bucket'ı temizle
aws s3 rm s3://<bucket-name> --recursive
aws s3api delete-bucket --bucket <bucket-name>

# ECR repository'yi sil
aws ecr delete-repository --repository-name mnist-training --force
```

## Son 
Evet süper şimdi AWS Training operasyonu öğrenmiş olduk umarım bu aşamaya kadar sorunsuz bir şekilde gelebilmişsinizdir. Takıldığınız bir nokta olursa hem Selman'ın grubundan veya Linkedin'den ulaşabilirsiniz. Elimden geldiğince destek olmak isterim. 
