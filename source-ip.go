package main

import (
	"context"
	"encoding/json"
	"log"
	"net"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type IPResponse struct {
	SourceIP string `json:"sourceIP"`
}

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

func getHeaderValue(headers map[string]string, key string) string {
	// Try exact match first
	if value, exists := headers[key]; exists {
		return value
	}

	// Try case-insensitive match
	lowerKey := strings.ToLower(key)
	for k, v := range headers {
		if strings.ToLower(k) == lowerKey {
			return v
		}
	}

	return ""
}

func isValidIP(ip string) bool {
	return net.ParseIP(ip) != nil
}

func getClientIP(headers map[string]string) string {
	// Try X-Forwarded-For first (most common in AWS ALB/CloudFront)
	xForwardedFor := getHeaderValue(headers, "X-Forwarded-For")
	if xForwardedFor != "" {
		// Split by comma and take the first valid IP
		ips := strings.Split(xForwardedFor, ",")
		for _, ip := range ips {
			cleanIP := strings.TrimSpace(ip)
			if isValidIP(cleanIP) && !isPrivateIP(cleanIP) {
				return cleanIP
			}
		}
	}

	// Fallback to X-Real-IP
	if xRealIP := getHeaderValue(headers, "X-Real-IP"); xRealIP != "" && isValidIP(xRealIP) {
		return xRealIP
	}

	// Last resort: try CloudFront-Viewer-Address (if using CloudFront)
	if cfViewerAddr := getHeaderValue(headers, "CloudFront-Viewer-Address"); cfViewerAddr != "" {
		// CloudFront-Viewer-Address format: "ip:port"
		if colonIndex := strings.LastIndex(cfViewerAddr, ":"); colonIndex > 0 {
			ip := cfViewerAddr[:colonIndex]
			if isValidIP(ip) {
				return ip
			}
		}
	}

	return "unknown"
}

func isPrivateIP(ip string) bool {
	parsedIP := net.ParseIP(ip)
	if parsedIP == nil {
		return false
	}

	// Check for private IP ranges
	privateRanges := []string{
		"10.0.0.0/8",
		"172.16.0.0/12",
		"192.168.0.0/16",
		"127.0.0.0/8",
	}

	for _, cidr := range privateRanges {
		_, network, err := net.ParseCIDR(cidr)
		if err != nil {
			continue
		}
		if network.Contains(parsedIP) {
			return true
		}
	}

	return false
}

func createErrorResponse(statusCode int, error, message string) events.APIGatewayProxyResponse {
	errorResponse := ErrorResponse{
		Error:   error,
		Message: message,
	}

	responseBody, _ := json.Marshal(errorResponse)

	return events.APIGatewayProxyResponse{
		StatusCode: statusCode,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(responseBody),
	}
}

func handler(ctx context.Context, event events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Extract client IP
	sourceIP := getClientIP(event.Headers)

	// Log request (without sensitive headers)
	log.Printf("Processing request from IP: %s, Method: %s, Path: %s",
		sourceIP, event.HTTPMethod, event.Path)

	// Build response
	response := IPResponse{
		SourceIP: sourceIP,
	}

	responseBody, err := json.Marshal(response)
	if err != nil {
		log.Printf("Failed to marshal response: %v", err)
		return createErrorResponse(500, "internal_server_error", "Failed to process request"), nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Headers: map[string]string{
			"Content-Type":                 "application/json",
			"Access-Control-Allow-Origin":  "*",
			"Access-Control-Allow-Methods": "GET, POST, OPTIONS",
			"Access-Control-Allow-Headers": "Content-Type",
		},
		Body: string(responseBody),
	}, nil
}

func main() {
	lambda.Start(handler)
}
