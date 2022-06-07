package main

import (
	"fmt"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type PostInput struct {
	IpAddress string `json:"ipAddress"`
}

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	fmt.Printf("event.HTTPMethod %v\n", request.HTTPMethod)
	fmt.Printf("event.Body %v\n", request.Body)
	fmt.Printf("event.QueryStringParameters %v\n", request.QueryStringParameters)
	fmt.Printf("event %v\n", request)

	ipAddress := ""

	if request.HTTPMethod == "GET" {
		ipAddress = request.QueryStringParameters["ipAddress"]
	}

	body := fmt.Sprintf("{\"message\": \"%s\"}", ipAddress)

	return events.APIGatewayProxyResponse{
		Body:       body,
		StatusCode: 200,
		Headers: map[string]string{
			"Content-Type":                 "application/json",
			"Access-Control-Allow-Headers": "Content-Type",
			"Access-Control_Allow-Methods": "GET",
			"Access-Control-Allow-Origin":  "*",
		},
	}, nil

}

func main() {
	lambda.Start(handler)
}
