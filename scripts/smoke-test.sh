#!/usr/bin/env bash
# Uses the current kubeconfig; never creates or destroys AWS infrastructure.
set -euo pipefail
cd "$(dirname "$0")/.."
namespace="${NAMESPACE:-eks-smoke}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
NAMESPACE="$namespace" bash examples/sample-app/deploy.sh
kubectl -n "$namespace" wait --for=jsonpath='{.status.phase}'=Bound pvc/sample-app-storage --timeout=300s
kubectl -n "$namespace" exec deployment/sample-nginx-app -- wget -qO- http://sample-nginx-service/ | grep -q 'EKS Sample Application'
kubectl -n "$namespace" exec deployment/sample-nginx-app -- nslookup kubernetes.default.svc.cluster.local
kubectl -n "$namespace" exec deployment/sample-app-with-storage -- sh -c 'echo persistent-smoke > /data/smoke.txt'
pod="$(kubectl -n "$namespace" get pods -l app=sample-app-with-storage -o jsonpath='{.items[0].metadata.name}')"
kubectl -n "$namespace" delete pod "$pod" --wait=true
kubectl -n "$namespace" rollout status deployment/sample-app-with-storage --timeout=300s
kubectl -n "$namespace" exec deployment/sample-app-with-storage -- cat /data/smoke.txt | grep -q persistent-smoke
kubectl top nodes
kubectl -n "$namespace" wait --for=condition=ScalingActive hpa/sample-nginx-hpa --timeout=300s
hostname=""
for ((attempt=0; attempt<60; attempt++)); do
  hostname="$(kubectl -n "$namespace" get ingress sample-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
  if [[ -n "$hostname" ]]; then break; fi
  sleep 5
done
[[ -n "$hostname" ]] || { echo 'Ingress did not get an ALB hostname' >&2; exit 1; }
curl --fail --retry 30 --retry-all-errors --retry-delay 5 "http://$hostname/" | grep -q 'EKS Sample Application'
echo "Smoke test passed for namespace $namespace"
