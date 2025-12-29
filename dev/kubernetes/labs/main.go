package main

import (
	"context"
	"flag"
	"os"
)

func main() {
	ctx := context.Background()
	resource := flag.String("resource", "deployment", "Name of the resource to debug (deployment or ingress)")
	defaultNs := os.Getenv("DEFAULT_NAMESPACE")
	if defaultNs == "" {
		defaultNs = "default"
	}
	namespace := flag.String("namespace", defaultNs, "Namespace of the resource")
	labRef := flag.String("lab", "", "Ref of the lab to run")
	flag.Parse()

	if labRef == nil || *labRef == "" {
		runLocalAnalyzer(ctx, *resource, *namespace)
	} else {
		runLab(ctx, *labRef)
	}
}
