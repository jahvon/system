package main

import (
	"fmt"
	"strings"

	appsv1 "k8s.io/api/apps/v1"
)

func analyzeDeployment(dep *appsv1.Deployment) {
	fmt.Printf("Analyzing Deployment '%s' in Namespace '%s':\n", dep.Name, dep.Namespace)

	created := dep.ObjectMeta.CreationTimestamp
	fmt.Printf("Created: %s\n", created)
	var images []string
	for _, container := range dep.Spec.Template.Spec.Containers {
		images = append(images, formatImage(container.Image))
	}
	fmt.Printf("Images:\n  - %s\n", strings.Join(images, "\n"))

	fmt.Printf("Replicas: %d/%d\n", dep.Status.ReadyReplicas, dep.Status.Replicas)
	if dep.Status.ReadyReplicas == dep.Status.Replicas {
		fmt.Println("All pods are ready.")
	} else {
		fmt.Printf("Only %d/%d pods are ready.\n", dep.Status.ReadyReplicas, dep.Status.Replicas)
		fmt.Println("Check the logs of the pods for any errors or issues.")
	}

	fmt.Println("Status Check:")
	var unhealthy bool
	for _, condition := range dep.Status.Conditions {
		fmt.Println("  -", condition.Type, ":", condition.Message)
		if condition.Status == "False" {
			unhealthy = true
		}
	}
	if unhealthy {
		fmt.Println("The Deployment is unhealthy. Check the events for more information.")
	}

	//
	// fmt.Println("Last 10 Log Lines (Across All Pods):")
	// podList, err := clientset.CoreV1().Pods(namespace).List(ctx, metav1.ListOptions{LabelSelector: fmt.Sprintf("app=%s", deploymentName)})
	// if err != nil {
	// 	fmt.Printf("Error retrieving pods for Deployment: %v\n", err)
	// 	return
	// }
	// for _, pod := range podList.Items {
	// 	podLogs, err := clientset.CoreV1().Pods(namespace).GetLogs(pod.Name, &v1.PodLogOptions{}).DoRaw(ctx)
	// 	if err != nil {
	// 		fmt.Printf("Error retrieving logs for pod %s: %v\n", pod.Name, err)
	// 		continue
	// 	}
	// 	logLines := strings.Split(string(podLogs), "\n")
	// 	for i := len(logLines) - 1; i >= 0 && i >= len(logLines)-10; i-- {
	// 		fmt.Printf("[%s] %s\n", pod.Name, logLines[i])
	// 	}
	// }
}

func formatImage(image string) string {
	var name string
	slashSplit := strings.Split(image, "/")
	if len(slashSplit) > 1 {
		image = slashSplit[1]
	}

	if colonSplit := strings.Split(image, ":"); len(colonSplit) > 1 {
		name = image
	} else if shaSplit := strings.Split(image, "@"); len(shaSplit) > 1 {
		// shorten the sha to 12 characters
		name = fmt.Sprintf("%s@%s", shaSplit[0], shaSplit[1][0:12])
	} else {
		name = image
	}

	return name
}
