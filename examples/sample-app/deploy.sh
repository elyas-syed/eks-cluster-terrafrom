#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
namespace="${NAMESPACE:-default}"
kubectl get namespace "$namespace" >/dev/null
kubectl apply -f storage-class.yaml
for manifest in deployment.yaml service.yaml persistent-volume.yaml ingress.yaml hpa.yaml; do
  kubectl -n "$namespace" apply -f "$manifest"
done
kubectl -n "$namespace" rollout status deployment/sample-nginx-app --timeout=300s
kubectl -n "$namespace" rollout status deployment/sample-app-with-storage --timeout=300s
kubectl -n "$namespace" get pods,pvc,ingress,hpa
