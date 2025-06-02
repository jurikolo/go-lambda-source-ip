package main

import (
	"context"
	"log"
	"net/http"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	ginadapter "github.com/awslabs/aws-lambda-go-api-proxy/gin"
	"github.com/gin-gonic/gin"
)

var ginLambda *ginadapter.GinLambda

func init() {
	// Initialize the Gin router
	router := NewRouter()
	ginLambda = ginadapter.New(router)
}

func NewRouter() *gin.Engine {
	// Set the router as the default one shipped with Gin
	router := gin.Default()

	// Setup Security Headers
	router.Use(func(c *gin.Context) {
		c.Next()
	})

	// Setup route group for the API
	router.POST("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"sourceIp": c.PostForm("sourceIp"),
		})
	})

	return router
}

func Handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	log.Printf("Request headers: %s", req.Headers)
	log.Printf("Request body: %s", req.Body)
	return ginLambda.ProxyWithContext(ctx, req)
}

func main() {
	lambda.Start(Handler)
}