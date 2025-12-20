#!/bin/bash

# AWS ZERO to YETO - EKS Deployment Script (Frankfurt)
# Bu script EKS cluster + örnek nginx Deployment/Service (LB) deploy eder.

set -euo pipefail

# Renkli çıktı
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Ayarlar (env ile override edilebilir)
REGION="${REGION:-eu-central-1}"            # Frankfurt Region
CLUSTER_NAME="${CLUSTER_NAME:-demo-eks-$(date +%s)}"
NODES="${NODES:-2}"
NODE_TYPE="${NODE_TYPE:-t3.medium}"
NAMESPACE="${NAMESPACE:-default}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YAML_FILE="${YAML_FILE:-$SCRIPT_DIR/hello.yaml}"
STATE_FILE="$SCRIPT_DIR/eks-config.json"

# Komut kontrolleri
need_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    print_error "Gerekli komut bulunamadı: $c"
    exit 1
  fi
}

check_prereqs() {
  need_cmd aws
  need_cmd kubectl
  need_cmd eksctl

  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS kimlik bilgileri hazır değil. 'aws configure' veya env creds ayarlayın."
    exit 1
  fi

  print_success "Prereq OK: aws, kubectl, eksctl ve AWS credentials hazır"
}

create_yaml_if_missing() {
  if [ -f "$YAML_FILE" ]; then
    print_info "YAML bulundu: $YAML_FILE"
    return 0
  fi

  print_warning "YAML bulunamadı, örnek hello.yaml oluşturuyorum: $YAML_FILE"
  cat > "$YAML_FILE" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
        - name: hello
          image: nginx:stable
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: hello-svc
spec:
  type: LoadBalancer
  selector:
    app: hello
  ports:
    - port: 80
      targetPort: 80
EOF
  print_success "hello.yaml oluşturuldu"
}

# Daha güvenli cluster var mı kontrolü (ismi JSON'dan arar)
cluster_exists() {
  # eksctl get cluster -o json çıktısında "Name": "xxx" aranır
  eksctl get cluster --region "$REGION" -o json 2>/dev/null | grep -q "\"Name\": \"${CLUSTER_NAME}\""
}

create_cluster() {
  print_info "EKS cluster oluşturuluyor..."
  print_info "Cluster: $CLUSTER_NAME"
  print_info "Region : $REGION"
  print_info "Nodes  : $NODES x $NODE_TYPE (managed nodegroup)"

  if cluster_exists; then
    print_warning "Cluster zaten var: $CLUSTER_NAME (oluşturmadan devam)"
    return 0
  fi

  # Basit ve stabil create cluster
  eksctl create cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --nodes "$NODES" \
    --node-type "$NODE_TYPE" \
    --managed

  print_success "Cluster oluşturuldu: $CLUSTER_NAME"
}

update_kubeconfig() {
  print_info "kubeconfig bağlanıyor..."
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" >/dev/null
  print_success "kubeconfig OK (context: $(kubectl config current-context))"
}

ensure_namespace() {
  if [ "$NAMESPACE" = "default" ]; then
    return 0
  fi

  if kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
    print_info "Namespace mevcut: $NAMESPACE"
  else
    print_info "Namespace oluşturuluyor: $NAMESPACE"
    kubectl create ns "$NAMESPACE" >/dev/null
    print_success "Namespace oluşturuldu: $NAMESPACE"
  fi
}

deploy_workload() {
  print_info "Kubernetes kaynakları deploy ediliyor..."
  ensure_namespace

  kubectl apply -n "$NAMESPACE" -f "$YAML_FILE"
  print_success "apply OK"

  print_info "Rollout bekleniyor (deployment/hello)..."
  kubectl rollout status -n "$NAMESPACE" deployment/hello --timeout=180s
  print_success "deployment hazır"
}

wait_for_lb() {
  print_info "LoadBalancer endpoint bekleniyor (service/hello-svc)..."
  local tries=60
  local sleep_s=10
  local hostname=""
  local ip=""

  for i in $(seq 1 "$tries"); do
    hostname="$(kubectl get svc hello-svc -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    ip="$(kubectl get svc hello-svc -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"

    if [ -n "$hostname" ] || [ -n "$ip" ]; then
      print_success "LoadBalancer endpoint geldi"
      if [ -n "$hostname" ]; then
        echo "$hostname"
      else
        echo "$ip"
      fi
      return 0
    fi

    print_info "Henüz yok... ($i/$tries) ${sleep_s}s bekleniyor"
    sleep "$sleep_s"
  done

  print_warning "LB endpoint zamanında gelmedi. Yine de kaynaklar deploy edildi."
  return 1
}

write_state() {
  print_info "State dosyası yazılıyor: $STATE_FILE"
  cat > "$STATE_FILE" <<EOF
{
  "cluster_name": "$CLUSTER_NAME",
  "region": "$REGION",
  "namespace": "$NAMESPACE",
  "yaml_file": "$YAML_FILE"
}
EOF
  print_success "State yazıldı"
}

show_summary() {
  echo ""
  print_success "🎉 EKS deployment tamamlandı!"
  print_info "Cluster : $CLUSTER_NAME"
  print_info "Region  : $REGION"
  print_info "NS      : $NAMESPACE"
  print_info "YAML    : $YAML_FILE"
  echo ""
  print_info "Kontrol komutları:"
  echo "  kubectl get nodes"
  echo "  kubectl get deploy,po,svc -n $NAMESPACE"
  echo "  kubectl describe svc hello-svc -n $NAMESPACE"
  echo ""
  print_warning "💸 Not: EKS + LoadBalancer maliyet çıkarır. İşin bitince cleanup.sh çalıştır."
}

main() {
  print_info "🚀 EKS Deployment başlatılıyor..."
  check_prereqs
  create_yaml_if_missing
  create_cluster
  update_kubeconfig
  deploy_workload

  # endpoint çıktısındaki newline temizlensin
  endpoint="$(wait_for_lb 2>/dev/null | tr -d '\n' || true)"

  write_state
  show_summary

  if [ -n "${endpoint:-}" ]; then
    print_success "🌍 Endpoint (HTTP): http://$endpoint"
    print_info "Test: curl -I http://$endpoint"
  else
    print_warning "Endpoint yoksa: 'kubectl get svc hello-svc -n $NAMESPACE -w' ile bekleyebilirsin."
  fi
}

main "$@"