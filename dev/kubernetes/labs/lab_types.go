package main

import (
	appsv1 "k8s.io/api/apps/v1"
	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
)

var testDeployment = &appsv1.Deployment{
	ObjectMeta: metav1.ObjectMeta{
		Name:      "test-deployment",
		Namespace: "default",
	},
	Spec: appsv1.DeploymentSpec{
		Replicas: int32Ptr(3),
		Selector: &metav1.LabelSelector{
			MatchLabels: map[string]string{
				"app": "test-deployment",
			},
		},
		Template: v1.PodTemplateSpec{
			ObjectMeta: metav1.ObjectMeta{
				Labels: map[string]string{
					"app": "test-deployment",
				},
			},
			Spec: v1.PodSpec{
				Containers: []v1.Container{
					{
						Name:  "test-container",
						Image: "test-image",
						Ports: []v1.ContainerPort{
							{
								ContainerPort: 80,
								Name:          "http",
							},
						},
						LivenessProbe: &v1.Probe{
							ProbeHandler: v1.ProbeHandler{
								HTTPGet: &v1.HTTPGetAction{
									Path: "/health",
									Port: intstr.FromInt32(8080),
								},
							},
							InitialDelaySeconds: 15,
							TimeoutSeconds:      30,
						},
						Resources: v1.ResourceRequirements{
							Limits: v1.ResourceList{
								v1.ResourceCPU:    resource.MustParse("1"),
								v1.ResourceMemory: resource.MustParse("1Gi"),
							},
							Requests: v1.ResourceList{
								v1.ResourceCPU:    resource.MustParse("0.5"),
								v1.ResourceMemory: resource.MustParse("512Mi"),
							},
						},
					},
				},
			},
		},
		Strategy: appsv1.DeploymentStrategy{
			Type: appsv1.RollingUpdateDeploymentStrategyType,
			RollingUpdate: &appsv1.RollingUpdateDeployment{
				MaxUnavailable: &intstr.IntOrString{
					Type:   intstr.String,
					StrVal: "25%",
				},
				MaxSurge: &intstr.IntOrString{
					Type:   intstr.String,
					StrVal: "25%",
				},
			},
		},
	},
	Status: appsv1.DeploymentStatus{
		Replicas:            3,
		UpdatedReplicas:     3,
		ReadyReplicas:       3,
		AvailableReplicas:   3,
		UnavailableReplicas: 0,
		Conditions: []appsv1.DeploymentCondition{
			{
				Type:   appsv1.DeploymentAvailable,
				Status: v1.ConditionTrue,
				Reason: "MinimumReplicasAvailable",
			},
		},
	},
}

func int32Ptr(i int32) *int32 {
	return &i
}
