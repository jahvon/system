package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

func runLocalAnalyzer(ctx context.Context, resource string, namespace string) {
	kubeconfig := filepath.Join(os.Getenv("HOME"), ".kube", "config")
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		fmt.Printf("Error loading kubeconfig: %v\n", err)
		os.Exit(1)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		fmt.Printf("Error creating Kubernetes clientset: %v\n", err)
		os.Exit(1)
	}

	// Retrieve resource details
	switch flag.Arg(0) {
	case "deployment":
		describeDeployment(ctx, clientset, resource, namespace)
	case "ingress":
		describeIngress(ctx, clientset, resource, namespace)
	default:
		fmt.Println("Invalid resource type. Please specify either 'deployment' or 'ingress'.")
		os.Exit(1)
	}
}

func describeDeployment(ctx context.Context, clientset *kubernetes.Clientset, deploymentName, namespace string) {
	fmt.Printf("Describing Deployment '%s' in Namespace '%s':\n", deploymentName, namespace)
	deployment, err := clientset.AppsV1().Deployments(namespace).
		Get(ctx, deploymentName, metav1.GetOptions{})
	if err != nil {
		fmt.Printf("Error describing Deployment: %v\n", err)
		return
	}
	fmt.Println("Status:")
	fmt.Println(deployment.Status)
	fmt.Printf("Replicas: %d/%d\n", deployment.Status.ReadyReplicas, deployment.Status.Replicas)
	if deployment.Status.ReadyReplicas == deployment.Status.Replicas {
		fmt.Println("All pods are ready.")
	} else {
		fmt.Printf("Only %d/%d pods are ready.\n", deployment.Status.ReadyReplicas, deployment.Status.Replicas)
		fmt.Println("Check the logs of the pods for any errors or issues.")
	}
	fmt.Println("Events:")
	events, err := clientset.CoreV1().Events(namespace).List(ctx, metav1.ListOptions{
		FieldSelector: fmt.Sprintf("involvedObject.name=%s,involvedObject.namespace=%s", deploymentName, namespace),
	})
	if err != nil {
		fmt.Printf("Error retrieving events for Deployment: %v\n", err)
		return
	}
	for _, event := range events.Items {
		fmt.Printf("LastSeen: %v, Type: %s, Reason: %s, Message: %s\n", event.LastTimestamp, event.Type, event.Reason, event.Message)
	}
	fmt.Println("Last 10 Log Lines (Across All Pods):")
	podList, err := clientset.CoreV1().Pods(namespace).List(ctx, metav1.ListOptions{LabelSelector: fmt.Sprintf("app=%s", deploymentName)})
	if err != nil {
		fmt.Printf("Error retrieving pods for Deployment: %v\n", err)
		return
	}
	for _, pod := range podList.Items {
		podLogs, err := clientset.CoreV1().Pods(namespace).GetLogs(pod.Name, &v1.PodLogOptions{}).DoRaw(ctx)
		if err != nil {
			fmt.Printf("Error retrieving logs for pod %s: %v\n", pod.Name, err)
			continue
		}
		logLines := strings.Split(string(podLogs), "\n")
		for i := len(logLines) - 1; i >= 0 && i >= len(logLines)-10; i-- {
			fmt.Printf("[%s] %s\n", pod.Name, logLines[i])
		}
	}
}

func describeIngress(ctx context.Context, clientset *kubernetes.Clientset, ingressName, namespace string) {
	fmt.Printf("Describing Ingress '%s' in Namespace '%s':\n", ingressName, namespace)
	ingress, err := clientset.NetworkingV1().Ingresses(namespace).
		Get(ctx, ingressName, metav1.GetOptions{})
	if err != nil {
		fmt.Printf("Error describing Ingress: %v\n", err)
		return
	}
	fmt.Println("Ingress Rules:")
	for _, rule := range ingress.Spec.Rules {
		fmt.Printf("Host: %s\n", rule.Host)
		for _, path := range rule.HTTP.Paths {
			fmt.Printf("  Path: %s\n", path.Path)
		}
	}
	fmt.Println("TLS:")
	for _, tls := range ingress.Spec.TLS {
		fmt.Printf("Secret: %s\n", tls.SecretName)
		fmt.Printf("  Hosts: %s\n", strings.Join(tls.Hosts, ", "))
	}
	fmt.Println("Status:")
	fmt.Println(ingress.Status)
	fmt.Println("Events:")
	events, err := clientset.CoreV1().Events(namespace).List(ctx, metav1.ListOptions{
		FieldSelector: fmt.Sprintf("involvedObject.name=%s,involvedObject.namespace=%s", ingressName, namespace),
	})
	if err != nil {
		fmt.Printf("Error retrieving events for Ingress: %v\n", err)
		return
	}
	for _, event := range events.Items {
		fmt.Printf("LastSeen: %v, Type: %s, Reason: %s, Message: %s\n", event.LastTimestamp, event.Type, event.Reason, event.Message)
	}
}
