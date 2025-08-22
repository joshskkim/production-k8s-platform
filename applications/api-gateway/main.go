package main

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "os/signal"
    "time"

    "github.com/gorilla/mux"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics collectors for monitoring
var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "api_gateway_requests_total",
            Help: "Total number of API requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "api_gateway_request_duration_seconds",
            Help:    "Duration of API requests",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
)

func init() {
    // Register Prometheus metrics
    prometheus.MustRegister(requestsTotal)
    prometheus.MustRegister(requestDuration)
}

// HealthResponse represents the health check response
type HealthResponse struct {
    Status    string            `json:"status"`
    Timestamp time.Time         `json:"timestamp"`
    Version   string            `json:"version"`
    Checks    map[string]string `json:"checks"`
}

// Middleware for request logging and metrics
func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        
        // Wrap the response writer to capture status code
        wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
        
        // Process request
        next.ServeHTTP(wrapped, r)
        
        // Record metrics
        duration := time.Since(start)
        requestsTotal.WithLabelValues(r.Method, r.URL.Path, fmt.Sprintf("%d", wrapped.statusCode)).Inc()
        requestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration.Seconds())
        
        // Log request
        log.Printf("%s %s %d %v", r.Method, r.URL.Path, wrapped.statusCode, duration)
    })
}

// Response writer wrapper to capture status code
type responseWriter struct {
    http.ResponseWriter
    statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.statusCode = code
    rw.ResponseWriter.WriteHeader(code)
}

// Health check endpoint with comprehensive checks
func healthHandler(w http.ResponseWriter, r *http.Request) {
    checks := make(map[string]string)
    
    // Check database connectivity (simulated)
    checks["database"] = "ok"
    
    // Check Redis connectivity (simulated)
    checks["redis"] = "ok"
    
    // Check external dependencies (simulated)
    checks["external_api"] = "ok"
    
    response := HealthResponse{
        Status:    "healthy",
        Timestamp: time.Now(),
        Version:   "v1.0.0",
        Checks:    checks,
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

// Readiness check endpoint
func readinessHandler(w http.ResponseWriter, r *http.Request) {
    // Perform readiness checks (database connectivity, etc.)
    response := map[string]interface{}{
        "status": "ready",
        "timestamp": time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

// Main API handler - routes requests to appropriate services
func apiHandler(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    service := vars["service"]
    
    // Route to appropriate microservice based on path
    switch service {
    case "users":
        proxyToUserService(w, r)
    case "data":
        proxyToDataService(w, r)
    default:
        http.Error(w, "Service not found", http.StatusNotFound)
    }
}

// Proxy to user service (simulated)
func proxyToUserService(w http.ResponseWriter, r *http.Request) {
    response := map[string]interface{}{
        "service": "user-service",
        "method":  r.Method,
        "path":    r.URL.Path,
        "timestamp": time.Now(),
        "message": "Request forwarded to user service",
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

// Proxy to data processing service (simulated)
func proxyToDataService(w http.ResponseWriter, r *http.Request) {
    response := map[string]interface{}{
        "service": "data-processor",
        "method":  r.Method,
        "path":    r.URL.Path,
        "timestamp": time.Now(),
        "message": "Request forwarded to data processing service",
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func main() {
    // Get configuration from environment
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }
    
    metricsPort := os.Getenv("METRICS_PORT")
    if metricsPort == "" {
        metricsPort = "8090"
    }
    
    // Create router
    r := mux.NewRouter()
    
    // Add middleware
    r.Use(loggingMiddleware)
    
    // Health endpoints
    r.HandleFunc("/health", healthHandler).Methods("GET")
    r.HandleFunc("/ready", readinessHandler).Methods("GET")
    
    // API routes
    r.HandleFunc("/api/{service}/{path:.*}", apiHandler)
    r.HandleFunc("/api/{service}", apiHandler)
    
    // Create main server
    srv := &http.Server{
        Handler:      r,
        Addr:         ":" + port,
        WriteTimeout: 15 * time.Second,
        ReadTimeout:  15 * time.Second,
        IdleTimeout:  60 * time.Second,
    }
    
    // Create metrics server
    metricsMux := http.NewServeMux()
    metricsMux.Handle("/metrics", promhttp.Handler())
    metricsSrv := &http.Server{
        Handler: metricsMux,
        Addr:    ":" + metricsPort,
    }
    
    // Start metrics server
    go func() {
        log.Printf("Starting metrics server on port %s", metricsPort)
        if err := metricsSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("Metrics server failed to start: %v", err)
        }
    }()
    
    // Start main server
    go func() {
        log.Printf("Starting API Gateway on port %s", port)
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("Server failed to start: %v", err)
        }
    }()
    
    // Wait for interrupt signal to gracefully shutdown
    c := make(chan os.Signal, 1)
    signal.Notify(c, os.Interrupt)
    
    // Block until signal is received
    <-c
    
    log.Println("Shutting down gracefully...")
    
    // Create context with timeout for shutdown
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    
    // Shutdown servers
    srv.Shutdown(ctx)
    metricsSrv.Shutdown(ctx)
    
    log.Println("Server shutdown complete")
}