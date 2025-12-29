#!/bin/bash

# Environment variables
# NAMESPACE specifies the Kubernetes namespace where the debugging process will be started.
# DEPLOYMENT specifies the name of the deployment that will be used for debugging.
# EXECUTABLE specifies the name of the executable file that will be debugged.
# LOCAL_PORT specifies the local port to forward to the debugging container.

set -e

if [ -z "$NAMESPACE" ]; then echo "NAMESPACE is not set. Exiting."; exit 1; fi
if [ -z "$DEPLOYMENT" ]; then echo "DEPLOYMENT is not set. Exiting."; exit 1; fi
if [ -z "$EXECUTABLE" ]; then echo "EXECUTABLE is not set. Exiting."; exit 1; fi
if [ -z "$LOCAL_PORT" ]; then echo "LOCAL_PORT is not set. Exiting."; exit 1; fi

GO_VERSION=1.19
DLV_VERSION=1.22.0
DELVE_DEBUGGER_VERSION=0

selector=$(kubectl get deployment -n $NAMESPACE -o jsonpath="{.items[?(@.metadata.name=='$DEPLOYMENT')].spec.selector.matchLabels.app}")
if [ -z "$selector" ]; then echo "Deployment $DEPLOYMENT not found in namespace $NAMESPACE. Exiting."; exit 1; fi

pod=$(kubectl get pod -n $NAMESPACE -l app=$selector -o jsonpath="{.items[0].metadata.name}")
if [ -z "$pod" ]; then echo "Pod not found for deployment $DEPLOYMENT in namespace $NAMESPACE. Exiting."; exit 1; fi

container=$(kubectl get pod -n $NAMESPACE $pod -o jsonpath="{.spec.containers[0].name}")
if [ -z "$container" ]; then echo "Container not found for pod $pod in namespace $NAMESPACE. Exiting."; exit 1; fi

kubectl --namespace $1 port-forward pod/$pod $LOCAL_PORT:4000 &
PORT_FORWARDING_PID=$!
echo 'Please wait for the line "debug layer=debugger continuing" to appear...'
kubectl --namespace $NAMESPACE debug -it pod/$pod --image=ghcr.io/rancherlabs/delve-debugger:$DLV_VERSION-$DELVE_DEBUGGER_VERSION --target=$container --env="[EXECUTABLE=$EXECUTABLE]"
kill ${PORT_FORWARDING_PID}