#!/bin/bash

# Author Zakaria Moumen
# Email zmoumen@student.1337.ma

set -eo pipefail

# check if kubectl exists
if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is not installed. Please install it to proceed."
        exit 1
fi


# check if k3d exists
if ! command -v k3d &> /dev/null; then
        echo "Error: k3d is not installed. Please install it to proceed."
        exit 1
fi


# pin the subnet the cluster will use

k3d cluster create main --port '8067:80@loadbalancer' --port '8888:8888@loadbalancer'

kubectl wait --for=condition=Ready nodes --all --timeout=120s


# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# Custom resource definitions (CRDs)
kubectl apply --server-side --force-conflicts -k https://github.com/argoproj/argo-cd/manifests/crds\?ref\=stable

# disable builtin TLS and expose argocd-server
kubectl patch deployment argocd-server -n argocd --type='json'   -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--insecure"}]'
kubectl -n argocd create ingress argocd-ingress --rule="/*=argocd-server:80:prefix"


echo "Waiting for ArgoCD pods to be ready..."
kubectl wait -n argocd pods --all --for=condition=Ready --timeout=120s
if ! kubectl -n argocd get pods | grep -q "Running"; then
    echo "Error: ArgoCD pods are not running. Please check the status of the pods with 'kubectl -n argocd get pods'."
    exit 1
fi
echo "ArgoCD is ready and running."
# credentials for argocd
echo "==============================="
echo "ArgoCD is installed and accessible at http://localhost:8067"
echo "ArgoCD username: admin"
echo -n "ArgoCD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
echo "==============================="

