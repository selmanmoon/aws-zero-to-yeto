# Amazon Elastic Kubernetes Service (EKS)

## 📖 Servis Hakkında

Amazon Elastic Kubernetes Service (EKS), AWS’nin tam yönetilen Kubernetes servisidir.

Kısaca:
**E**  -> Elastic → Otomatik ölçeklenebilirlik
**K**  -> Kubernetes → Container orkestrasyon platformu
**S**  -> Service → AWS tarafından yönetilen servis

Amazon EKS (Elastic Kubernetes Service), AWS üzerinde tam yönetilen Kubernetes servisidir. Kubernetes control plane (API server, etcd vb.) AWS tarafından yönetilir; **EC2 node’lar**, **Fargate (serverless)** veya **Hybrid Nodes** üzerinde çalıştırılır. EKS; ölçeklenebilirlik, güvenlik ve AWS servisleriyle entegrasyon (IAM, VPC, ALB/NLB, EBS/EFS, CloudWatch) gibi konularda güçlü bir çözümdür.

## 🎯 EKS’in Temel Özellikleri

- **Managed Control Plane**: Kubernetes control plane AWS tarafından yönetilir HA (High Available (yüksek erişilebilirlik)).
- **Compute Seçenekleri**:
  - **Managed Node Groups (EC2)**: AWS’nin yönettiği node group’lar
  - **Fargate**: Pod bazlı serverless çalışma
  - **EKS Auto Mode**: Altyapı bileşenlerini daha fazla otomatikleştiren yönetim modu (compute otomasyonu dahil)
  - **Hybrid Nodes**: On-prem / edge tarafında EKS ile uyumlu çalışma
- **Managed Add-ons**: CoreDNS, kube-proxy, VPC CNI gibi kritik bileşenlerin AWS tarafından yönetilen sürümleri.
- **Güvenli IAM Erişimi (Pod Identity)**: Pod’lara AWS servislerine erişim için IAM rolü atamayı sadeleştirir.
- **AWS Networking Entegrasyonu**: VPC, Security Group, Load Balancer (ALB/NLB) ile uyum.
- **Observability**: CloudWatch, OpenTelemetry, Container Insights gibi seçeneklerle izleme.

---

## 💰 Ücretlendirme Notları (Özet)

- EKS **cluster başına saatlik** ücretlendirilir (Kubernetes sürümünün support durumuna göre değişir).
- **EKS, AWS Free Tier’a dahil değildir** (compute, LB, NAT, EBS/EFS vb. ek maliyetler de oluşabilir).
- Pratik ipucu: Küçük lab ortamında en büyük maliyet çoğu zaman **NAT Gateway + Load Balancer + cluster fee** olur.

> Not: Güncel fiyat ve support pencereleri AWS bölgesine göre değişebilir; en doğru bilgi için resmi pricing sayfasına bak.

---

## 🔧 Temel Kavramlar

### Control Plane vs Data Plane
- **Control Plane**: Kubernetes API Server, scheduler, etcd (AWS yönetir).
- **Data Plane**: Worker node’lar (EC2/Fargate/Hybrid) ve pod’ların çalıştığı katman (senin yönetim alanın).

### Node Group Türleri
- **Managed Node Group**: AWS node lifecycle yönetimini kolaylaştırır.
- **Self-managed Nodes**: Daha fazla kontrol (AMI/upgrade/scripting) ama daha çok operasyon yükü.
- **Fargate**: Node yönetimi yok; pod bazlı serverless.

### Add-ons (EKS Managed Add-ons)
- CoreDNS, kube-proxy, Amazon VPC CNI, EBS CSI Driver vb. kritik bileşenleri **AWS yönetimli** kurup güncelleyebilirsin.

### Pod Identity (IAM for Pods)
- Pod’ların AWS servislerine (S3, DynamoDB, SSM, Secrets Manager vb.) erişimi için **IAM rolü + Kubernetes ServiceAccount** eşlemesi sağlar.

-------

## 🧩 Hızlı Başlangıç (CLI)

### 1) Cluster oluşturma (eksctl örneği)
```bash
# Ön koşul: aws cli, kubectl, eksctl kurulu olmalı ve AWS credentials ayarlı olmalı.
eksctl create cluster \
  --name demo-eks \
  --region eu-central-1 \
  --nodes 2 \
  --node-type t3.medium \
  --managed

  Example.yaml dosyasini calistirmak icin
kubectl apply -f hello.yaml
kubectl get svc hello-svc


### Kubeconfig bağlama
aws eks update-kubeconfig --region eu-central-1 --name demo-eks
kubectl get nodes


▶️ Çalıştırma Adımları
cd services        # Servis dizinine geç
cd eks             # EKS dizinine geç
chmod +x deploy.sh cleanup.sh
./deploy.sh        # Deploy işlemi  ***
./cleanup.sh       # Cleanup işlemi ***


🧪 Test Senaryoları:
Microservice Platform (API gateway + backend servisler + HPA)
CI/CD ile GitOps (ArgoCD / FluxCD ile deploy)
Observability Stack (Prometheus/Grafana + CloudWatch)
Stateful Workloads (EBS/EFS CSI ile storage)
Security-by-Design (NetworkPolicy, Pod Identity, secrets yönetimi)

 Öğrenme Kaynakları:
- Amazon EKS User Guide: https://docs.aws.amazon.com/eks/latest/userguide/
- EKS Pricing: https://aws.amazon.com/eks/pricing/
- EKS Managed Add-ons: https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html
- EKS Pod Identity: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
- EKS Auto Mode: https://docs.aws.amazon.com/eks/latest/userguide/automode.html
