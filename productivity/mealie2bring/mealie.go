package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"time"
)

func GetThisWeeksMeals() {
	mealieClient := NewMealieClient()
	mealPlans, err := mealieClient.GetMealPlans(time.Now(), time.Now().AddDate(0, 0, 7))
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	for _, mealPlan := range mealPlans {
		fmt.Println(mealPlan)
	}
}

type MealieClient struct {
	client *http.Client
}

func NewMealieClient() *MealieClient {
	return &MealieClient{
		client: &http.Client{Timeout: time.Second * 10},
	}
}

var getRecipes = "/api/recipes"

func (m *MealieClient) GetRecipeDetails(recipe Recipe) (*Recipe, error) {
	requestUrl, err := url.JoinPath(mealieURL, getRecipes, recipe.ID)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequest("GET", requestUrl, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Add("Authorization", "Bearer "+mealieToken)
	resp, err := m.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var recipeDetails Recipe
	if err := json.NewDecoder(resp.Body).Decode(&recipeDetails); err != nil {
		return nil, err
	}

	return &recipeDetails, nil
}

var getMealPlans = "/api/groups/mealplans"

func (m *MealieClient) GetMealPlans(start, end time.Time) ([]Mealplan, error) {
	requestUrl, err := url.JoinPath(mealieURL, getMealPlans)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequest("GET", requestUrl, nil)
	if err != nil {
		return nil, err
	}
	q := req.URL.Query()
	q.Add("start_date", start.Format("2006-01-02"))
	q.Add("end_date", end.Format("2006-01-02"))
	q.Add("perPage", "50")
	req.URL.RawQuery = q.Encode()
	req.Header.Add("Authorization", "Bearer "+mealieToken)
	resp, err := m.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var mealPlans MealPlansResponse
	if err := json.NewDecoder(resp.Body).Decode(&mealPlans); err != nil {
		return nil, err
	}

	fmt.Printf("Got %d meal plans\n", len(mealPlans.Items))

	return mealPlans.Items, nil
}

type MealPlansResponse struct {
	Items      []Mealplan `json:"items"`
	Page       int        `json:"page"`
	PerPage    int        `json:"perPage"`
	Total      int        `json:"total"`
	TotalPages int        `json:"totalPages"`
}

type Mealplan struct {
	Date      string `json:"date"`
	EntryType string `json:"entryType"`
	Title     string `json:"title"`
	Text      string `json:"text"`
	RecipeID  string `json:"recipeId"`
	ID        int    `json:"id"`
	GroupID   string `json:"groupId"`
	UserID    string `json:"userId"`
	Recipe    Recipe `json:"recipe"`
}

type Recipe struct {
	ID             string   `json:"id"`
	UserID         string   `json:"userId"`
	GroupID        string   `json:"groupId"`
	Name           string   `json:"name"`
	Slug           string   `json:"slug"`
	Image          string   `json:"image"`
	RecipeYield    string   `json:"recipeYield"`
	TotalTime      string   `json:"totalTime"`
	PrepTime       string   `json:"prepTime"`
	CookTime       string   `json:"cookTime"`
	PerformTime    string   `json:"performTime"`
	Description    string   `json:"description"`
	RecipeCategory []string `json:"recipeCategory"`
	Tags           []string `json:"tags"`
	Tools          []string `json:"tools"`
	Rating         int      `json:"rating"`
	OrgURL         string   `json:"orgURL"`
	DateAdded      string   `json:"dateAdded"`
	DateUpdated    string   `json:"dateUpdated"`
	CreatedAt      string   `json:"createdAt"`
	UpdateAt       string   `json:"updateAt"`
	LastMade       string   `json:"lastMade"`

	// Only in recipe details
	Ingredients []Ingredient `json:"ingredients"`
}
