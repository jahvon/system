#!/bin/bash

# Environment variables
# ACTION specifies whether to install or uninstall httpbin. Default is "install".
# NAMESPACE specifies the Kubernetes namespace where httpbin will be deployed or uninstalled.

set -e

if [ -z "$NAMESPACE" ]; then echo "NAMESPACE is not set. Exiting."; exit 1; fi

if [ "$ACTION" == "uninstall" ]; then
  echo "Uninstalling httpbin from namespace $NAMESPACE..."
  kubectl delete -f httpbin.yaml -n $NAMESPACE
else
  echo "Deploying httpbin in namespace $NAMESPACE..."
  kubectl apply -f httpbin.yaml -n $NAMESPACE
  kubectl -n $NAMESPACE rollout status deployment/httpbin --timeout=5m
  kubectl -n $NAMESPACE get pods -l app=httpbin -o wide
fi
