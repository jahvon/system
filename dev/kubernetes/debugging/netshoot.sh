#!/bin/bash

# Environment variables
# ACTION specifies whether to temporarily exec, install or uninstall netshoot. Default is "exec".
# NAMESPACE specifies the Kubernetes namespace where netshoot will be deployed or uninstalled.

set -e

if [ -z "$NAMESPACE" ]; then echo "NAMESPACE is not set. Exiting."; exit 1; fi

# Check the action
if [ "$ACTION" == "exec" ]; then
    echo "Executing netshoot in namespace $NAMESPACE..."
    kubectl run netshoot --image=nicolaka/netshoot -n $NAMESPACE --rm -i --tty -- /bin/bash
elif [ "$ACTION" == "uninstall" ]; then
    echo "Uninstalling netshoot from namespace $NAMESPACE..."
    kubectl delete -f netshoot.yaml -n $NAMESPACE
else
    echo "Deploying netshoot in namespace $NAMESPACE..."
    kubectl apply -f netshoot.yaml -n $NAMESPACE
    kubectl -n $NAMESPACE rollout status deployment/netshoot-debugger --timeout=5m
fi
