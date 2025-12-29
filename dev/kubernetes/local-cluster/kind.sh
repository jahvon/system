#!/bin/bash

# Environment variables
# ACTION specifies whether to create or destroy the kind cluster. Allowed values are "create" or "destroy".
# CLUSTER_NAME specifies the name of the kind cluster to be created or destroyed.

set -e

if ! command -v kind &> /dev/null; then
  echo "kind could not be found. Please install it before running this script."
  exit 1
fi

if [ -z "$ACTION" ]; then echo "ACTION is not set. Exiting."; exit 1; fi
if [ -z "$CLUSTER_NAME" ]; then echo "CLUSTER_NAME is not set. Exiting."; exit 1; fi

CONFIG_FILE="kind-config.yaml"
case "$ACTION" in
  create)
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
      echo "Cluster $CLUSTER_NAME already exists. Exiting."
      exit 1
    fi

    if [ -f "$CONFIG_FILE" ]; then
      echo "Creating kind cluster named $CLUSTER_NAME using configuration file $CONFIG_FILE..."
      kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_FILE" --wait 90s
      kubectl cluster-info --context kind-"$CLUSTER_NAME"

      echo "Installing ingress-nginx controller..."
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
      echo "Waiting for the ingress-nginx controller to become ready..."
      kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s

      local_port=$(kubectl get svc ingress-nginx-controller --namespace ingress-nginx --output=jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
      echo "You can access the ingress-nginx controller at http://localhost:$local_port"
      echo "Tip: To access services via custom domain names, add entries to your /etc/hosts file like '127.0.0.1 yourservice.local', replacing 'yourservice.local' with your custom domain."
    else
      echo "Configuration file $CONFIG_FILE not found. Exiting."
      exit 1
    fi
    echo "Kind cluster $CLUSTER_NAME has been created successfully."
    ;;
  destroy)
    echo "Destroying kind cluster named $CLUSTER_NAME..."
    kind delete cluster --name "$CLUSTER_NAME"
    echo "Kind cluster $CLUSTER_NAME has been destroyed successfully."
    ;;
  *)
    echo "Invalid ACTION specified. Use 'create' to create a cluster or 'destroy' to delete it."
    exit 1
    ;;
esac
