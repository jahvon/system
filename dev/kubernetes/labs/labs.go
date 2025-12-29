package main

import (
	"fmt"
	"os"

	"context"

	"sigs.k8s.io/yaml"
)

func runLab(_ context.Context, labRef string) {
	switch labRef {
	case "print-deploy":
		labPrintDeploy()
	case "analyze-deploy":
		labAnalyzeDeploy()
	default:
		fmt.Println("Invalid lab reference")
		os.Exit(1)
	}
}

func labPrintDeploy() {
	yamlBytes, err := yaml.Marshal(testDeployment)
	if err != nil {
		panic(err)
	}
	fmt.Println(string(yamlBytes))
}

func labAnalyzeDeploy() {
	analyzeDeployment(testDeployment)
}
