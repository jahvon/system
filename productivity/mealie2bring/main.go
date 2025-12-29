package main

import (
	"fmt"
	"os"
)

var (
	mealieToken = os.Getenv("MEALIE_TOKEN")
	mealieURL   = os.Getenv("MEALIE_URL")
)

func main() {
	if mealieToken == "" || mealieURL == "" {
		fmt.Println("MEALIE_TOKEN or MEALIE_URL environment variable not set")
		os.Exit(1)
	}
	GetThisWeeksMeals()

}
