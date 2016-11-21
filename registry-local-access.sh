#!/usr/bin/env bash

set -e

if [ "$KUBECONFIG" == "" ]; then
    echo "Warning, KUBECONFIG is not set. You may have to set it first."
fi

POD=$(kubectl get pods --namespace kube-system -l k8s-app=kube-registry \
    -o template --template '{{range .items}}{{.metadata.name}} {{.status.phase}}{{"\n"}}{{end}}' \
    | grep Running | head -1 | cut -f1 -d' ')

echo $POD

kubectl port-forward --namespace kube-system $POD 5000:5000