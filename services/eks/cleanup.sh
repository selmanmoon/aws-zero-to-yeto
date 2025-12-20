#!/bin/bash

# AWS ZERO to YETO - EKS Cleanup Script (Frankfurt region)
# Bu script hello deployment/service'i ve EKS cluster'ı siler.

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/eks-config.json"

# Varsayılanlar (state yoksa env ile verilebilir)
REGION="${REGION:-eu-central-1}"
CLUSTER_NAME="${CLUSTER_NAME:-}"
NAMESPACE="${NAMESPACE:-default}"
YAML_FILE="${YAML_FILE:-$SCRIPT_DIR/hello.yaml}"

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

read_state() {
  if [ ! -f "$STATE_FILE" ]; then
    print_warning "State dosyası yok: $STATE_FILE"
    return 0
  fi

  print_info "State okunuyor: $STATE_FILE"

  if command -v jq >/dev/null 2>&1; then
    CLUSTER_NAME="$(jq -r '.cluster_name // empty' "$STATE_FILE")"
    REGION="$(jq -r '.region // empty' "$STATE_FILE")"
    NAMESPACE="$(jq -r '.namespace // "default"' "$STATE_FILE")"
    YAML_FILE="$(jq -r '.yaml_file // empty' "$STATE_FILE")"
  else
    CLUSTER_NAME="$(grep -oP '"cluster_name"\s*:\s*"\K[^"]+' "$STATE_FILE" 2>/dev/null || true)"
    REGION="$(grep -oP '"region"\s*:\s*"\K[^"]+' "$STATE_FILE" 2>/dev/null || true)"
    NAMESPACE="$(grep -oP '"namespace"\s*:\s*"\K[^"]+' "$STATE_FILE" 2>/dev/null || echo "default")"
    YAML_FILE="$(grep -oP '"yaml_file"\s*:\s*"\K[^"]+' "$STATE_FILE" 2>/dev/null || true)"
  fi

  # YAML boşsa default'a dön
  if [ -z "${YAML_FILE:-}" ]; then
    YAML_FILE="$SCRIPT_DIR/hello.yaml"
  fi
}

cluster_exists() {
  eksctl get cluster --region "$REGION" -o json 2>/dev/null | grep -q "\"Name\": \"${CLUSTER_NAME}\""
}

try_update_kubeconfig() {
  print_info "kubeconfig bağlanmayı deniyorum..."
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
}

delete_k8s_resources() {
  print_info "Kubernetes kaynakları siliniyor (hello / hello-svc)..."

  # Eğer cluster yoksa kubectl zaten çalışmayabilir; patlamasın diye || true
  kubectl delete svc hello-svc -n "$NAMESPACE" --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl delete deployment hello -n "$NAMESPACE" --ignore-not-found=true >/dev/null 2>&1 || true

  # YAML dosyası varsa komple delete de deneyebiliriz (idempotent)
  if [ -f "$YAML_FILE" ]; then
    kubectl delete -n "$NAMESPACE" -f "$YAML_FILE" --ignore-not-found=true >/dev/null 2>&1 || true
  fi

  print_success "K8s kaynakları için silme isteği gönderildi"
}

delete_cluster() {
  if [ -z "${CLUSTER_NAME:-}" ]; then
    print_error "CLUSTER_NAME yok. Şu şekilde çalıştırabilirsin:"
    echo "  CLUSTER_NAME=demo-eks-XXXX REGION=eu-central-1 ./cleanup.sh"
    exit 1
  fi

  # Cluster gerçekten yoksa eksctl delete hata verebilir; önce kontrol edip mesajı net verelim
  if ! cluster_exists; then
    print_warning "Cluster bulunamadı: $CLUSTER_NAME (muhtemelen zaten silinmiş)"
    return 0
  fi

  print_info "EKS cluster siliniyor (eksctl)..."
  eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION" || {
    print_warning "eksctl delete cluster hata verdi. (cluster zaten siliniyor olabilir) Devam ediyorum..."
    return 0
  }

  print_success "Cluster silindi: $CLUSTER_NAME"
}

cleanup_files() {
  print_info "State dosyası temizleniyor..."
  rm -f "$STATE_FILE" >/dev/null 2>&1 || true
  print_success "State temizlendi: $STATE_FILE"
}

show_summary() {
  echo ""
  print_success "🎉 EKS Cleanup Tamamlandı!"
  print_info "Region : $REGION"
  print_info "Cluster: ${CLUSTER_NAME:-"(yok)"}"
  print_info "NS     : $NAMESPACE"
  echo ""
}

main() {
  echo -e "${BLUE}🧹 EKS Cleanup Başlatılıyor...${NC}"
  check_prereqs
  read_state

  if [ -z "${CLUSTER_NAME:-}" ]; then
    print_error "State dosyasında CLUSTER_NAME yok ve env ile de verilmemiş."
    echo "Örnek:"
    echo "  CLUSTER_NAME=demo-eks-123 REGION=eu-central-1 ./cleanup.sh"
    exit 1
  fi

  print_info "Hedef -> Cluster: $CLUSTER_NAME | Region: $REGION | NS: $NAMESPACE"

  try_update_kubeconfig
  delete_k8s_resources
  delete_cluster
  cleanup_files
  show_summary
}

main "$@"
