package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/redis/go-redis/v9"
	"github.com/rs/cors"
	"golang.org/x/time/rate"
)

// Gateway represents the main API Gateway structure
type Gateway struct {
	router          *mux.Router
	redisClient     *redis.Client
	paymentService  *ServiceProxy
	config          *Config
	rateLimiters    map[string]*rate.Limiter
	circuitBreakers map[string]*CircuitBreaker
}

// Config holds the gateway configuration
type Config struct {
	Port                string
	PaymentServiceURL   string
	RedisURL           string
	JWTSecret          string
	RateLimitRPM       int
	CircuitBreakerThreshold int
	LogLevel           string
}

// ServiceProxy represents a backend service proxy
type ServiceProxy struct {
	Name    string
	URL     string
	Timeout time.Duration
	Client  *http.Client
}

// CircuitBreaker implements a basic circuit breaker pattern
type CircuitBreaker struct {
	failureCount    int
	successCount    int
	failureThreshold int
	timeout         time.Duration
	lastFailTime    time.Time
	state          string // "closed", "open", "half-open"
}

// Metrics for monitoring
var (
	requestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "api_gateway_requests_total",
			Help: "Total number of requests processed by the gateway",
		},
		[]string{"method", "endpoint", "status", "service"},
	)
	
	requestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "api_gateway_request_duration_seconds",
			Help:    "Duration of requests processed by the gateway",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint", "service"},
	)
	
	rateLimitHits = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "api_gateway_rate_limit_hits_total",
			Help: "Total number of rate limit hits",
		},
		[]string{"client_ip", "endpoint"},
	)
	
	circuitBreakerState = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "api_gateway_circuit_breaker_state",
			Help: "Circuit breaker state (0=closed, 1=open, 2=half-open)",
		},
		[]string{"service"},
	)
)

func init() {
	// Register Prometheus metrics
	prometheus.MustRegister(requestsTotal)
	prometheus.MustRegister(requestDuration)
	prometheus.MustRegister(rateLimitHits)
	prometheus.MustRegister(circuitBreakerState)
}

func main() {
	config := loadConfig()
	
	gateway := &Gateway{
		config:          config,
		rateLimiters:    make(map[string]*rate.Limiter),
		circuitBreakers: make(map[string]*CircuitBreaker),
	}
	
	// Initialize components
	gateway.initRedis()
	gateway.initServices()
	gateway.setupRoutes()
	
	// Setup graceful shutdown
	server := &http.Server{
		Addr:    ":" + config.Port,
		Handler: gateway.router,
	}
	
	go func() {
		log.Printf("🚀 API Gateway starting on port %s", config.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()
	
	// Wait for interrupt signal to gracefully shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	
	log.Println("🛑 Shutting down API Gateway...")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Gateway forced to shutdown: %v", err)
	}
	
	log.Println("✅ API Gateway stopped")
}

func loadConfig() *Config {
	return &Config{
		Port:                   getEnv("PORT", "8080"),
		PaymentServiceURL:      getEnv("PAYMENT_SERVICE_URL", "http://payment-service:8080"),
		RedisURL:              getEnv("REDIS_URL", "redis:6379"),
		JWTSecret:             getEnv("JWT_SECRET", "your-secret-key"),
		RateLimitRPM:          getEnvInt("RATE_LIMIT_RPM", 100),
		CircuitBreakerThreshold: getEnvInt("CIRCUIT_BREAKER_THRESHOLD", 5),
		LogLevel:              getEnv("LOG_LEVEL", "INFO"),
	}
}

func (g *Gateway) initRedis() {
	g.redisClient = redis.NewClient(&redis.Options{
		Addr: g.config.RedisURL,
		DB:   0,
	})
	
	// Test Redis connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	
	if err := g.redisClient.Ping(ctx).Err(); err != nil {
		log.Printf("⚠️  Redis connection failed: %v", err)
	} else {
		log.Println("✅ Redis connected successfully")
	}
}

func (g *Gateway) initServices() {
	g.paymentService = &ServiceProxy{
		Name:    "payment-service",
		URL:     g.config.PaymentServiceURL,
		Timeout: 30 * time.Second,
		Client: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
	
	// Initialize circuit breaker for payment service
	g.circuitBreakers["payment-service"] = &CircuitBreaker{
		failureThreshold: g.config.CircuitBreakerThreshold,
		timeout:         60 * time.Second,
		state:          "closed",
	}
}

func (g *Gateway) setupRoutes() {
	g.router = mux.NewRouter()
	
	// CORS configuration
	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: true,
	})
	
	// Apply middleware
	g.router.Use(g.loggingMiddleware)
	g.router.Use(g.metricsMiddleware)
	g.router.Use(g.rateLimitMiddleware)
	g.router.Use(c.Handler)
	
	// Health check endpoint
	g.router.HandleFunc("/health", g.healthHandler).Methods("GET")
	g.router.HandleFunc("/ready", g.readinessHandler).Methods("GET")
	
	// Metrics endpoint for Prometheus
	g.router.Handle("/metrics", promhttp.Handler()).Methods("GET")
	
	// API versioning
	v1 := g.router.PathPrefix("/api/v1").Subrouter()
	v1.Use(g.authMiddleware)
	
	// Payment service routes
	paymentRoutes := v1.PathPrefix("/payments").Subrouter()
	paymentRoutes.HandleFunc("/process", g.proxyToPaymentService).Methods("POST")
	paymentRoutes.HandleFunc("/status/{id}", g.proxyToPaymentService).Methods("GET")
	paymentRoutes.HandleFunc("/history", g.proxyToPaymentService).Methods("GET")
	paymentRoutes.HandleFunc("/refund", g.proxyToPaymentService).Methods("POST")
	
	// Fraud detection routes
	fraudRoutes := v1.PathPrefix("/fraud").Subrouter()
	fraudRoutes.HandleFunc("/check", g.fraudCheckHandler).Methods("POST")
	fraudRoutes.HandleFunc("/report", g.fraudReportHandler).Methods("POST")
	
	// Admin routes (with additional auth)
	adminRoutes := g.router.PathPrefix("/admin").Subrouter()
	adminRoutes.Use(g.adminAuthMiddleware)
	adminRoutes.HandleFunc("/stats", g.statsHandler).Methods("GET")
	adminRoutes.HandleFunc("/circuit-breaker/{service}", g.circuitBreakerHandler).Methods("GET", "POST")
	adminRoutes.HandleFunc("/rate-limits", g.rateLimitsHandler).Methods("GET")
}

// Middleware implementations

func (g *Gateway) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Create a response writer that captures the status code
		rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		
		next.ServeHTTP(rw, r)
		
		log.Printf("[%s] %s %s %d %v",
			r.Method,
			r.RequestURI,
			r.RemoteAddr,
			rw.statusCode,
			time.Since(start),
		)
	})
}

func (g *Gateway) metricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		
		next.ServeHTTP(rw, r)
		
		// Record metrics
		requestsTotal.WithLabelValues(
			r.Method,
			r.URL.Path,
			strconv.Itoa(rw.statusCode),
			"gateway",
		).Inc()
		
		requestDuration.WithLabelValues(
			r.Method,
			r.URL.Path,
			"gateway",
		).Observe(time.Since(start).Seconds())
	})
}

func (g *Gateway) rateLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		clientIP := getClientIP(r)
		
		// Get or create rate limiter for this IP
		limiter := g.getRateLimiter(clientIP)
		
		if !limiter.Allow() {
			rateLimitHits.WithLabelValues(clientIP, r.URL.Path).Inc()
			
			w.Header().Set("X-RateLimit-Limit", strconv.Itoa(g.config.RateLimitRPM))
			w.Header().Set("X-RateLimit-Remaining", "0")
			w.Header().Set("Retry-After", "60")
			
			http.Error(w, `{"error":"Rate limit exceeded","retry_after":60}`, http.StatusTooManyRequests)
			return
		}
		
		next.ServeHTTP(w, r)
	})
}

func (g *Gateway) authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip auth for health checks
		if strings.Contains(r.URL.Path, "/health") || strings.Contains(r.URL.Path, "/ready") {
			next.ServeHTTP(w, r)
			return
		}
		
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, `{"error":"Authorization header required"}`, http.StatusUnauthorized)
			return
		}
		
		// Basic JWT validation (in production, use proper JWT library)
		token := strings.TrimPrefix(authHeader, "Bearer ")
		if !g.validateJWT(token) {
			http.Error(w, `{"error":"Invalid or expired token"}`, http.StatusUnauthorized)
			return
		}
		
		// Add user context to request
		r.Header.Set("X-User-ID", g.extractUserFromJWT(token))
		next.ServeHTTP(w, r)
	})
}

func (g *Gateway) adminAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Additional admin authentication
		adminKey := r.Header.Get("X-Admin-Key")
		if adminKey != "admin-secret-key" { // In production, use proper admin auth
			http.Error(w, `{"error":"Admin access required"}`, http.StatusForbidden)
			return
		}
		
		next.ServeHTTP(w, r)
	})
}

// Handler implementations

func (g *Gateway) healthHandler(w http.ResponseWriter, r *http.Request) {
	health := map[string]interface{}{
		"status":    "healthy",
		"timestamp": time.Now().UTC(),
		"version":   "1.0.0",
		"services": map[string]string{
			"payment-service": g.checkServiceHealth(g.paymentService),
			"redis":          g.checkRedisHealth(),
		},
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(health)
}

func (g *Gateway) readinessHandler(w http.ResponseWriter, r *http.Request) {
	ready := g.checkServiceHealth(g.paymentService) == "healthy" && g.checkRedisHealth() == "healthy"
	
	if ready {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{"status": "not ready"})
	}
}

func (g *Gateway) proxyToPaymentService(w http.ResponseWriter, r *http.Request) {
	// Check circuit breaker
	cb := g.circuitBreakers["payment-service"]
	if !cb.canExecute() {
		http.Error(w, `{"error":"Payment service temporarily unavailable"}`, http.StatusServiceUnavailable)
		return
	}
	
	// Forward request to payment service
	targetURL := g.paymentService.URL + r.URL.Path
	if r.URL.RawQuery != "" {
		targetURL += "?" + r.URL.RawQuery
	}
	
	proxyReq, err := http.NewRequest(r.Method, targetURL, r.Body)
	if err != nil {
		cb.recordFailure()
		http.Error(w, `{"error":"Failed to create proxy request"}`, http.StatusInternalServerError)
		return
	}
	
	// Copy headers
	for key, values := range r.Header {
		for _, value := range values {
			proxyReq.Header.Add(key, value)
		}
	}
	
	// Add request ID for tracing
	requestID := generateRequestID()
	proxyReq.Header.Set("X-Request-ID", requestID)
	w.Header().Set("X-Request-ID", requestID)
	
	resp, err := g.paymentService.Client.Do(proxyReq)
	if err != nil {
		cb.recordFailure()
		http.Error(w, `{"error":"Payment service unavailable"}`, http.StatusServiceUnavailable)
		return
	}
	defer resp.Body.Close()
	
	cb.recordSuccess()
	
	// Copy response
	w.WriteHeader(resp.StatusCode)
	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}
	
	// Copy body
	buf := make([]byte, 32*1024)
	for {
		n, err := resp.Body.Read(buf)
		if n > 0 {
			w.Write(buf[:n])
		}
		if err != nil {
			break
		}
	}
}

func (g *Gateway) fraudCheckHandler(w http.ResponseWriter, r *http.Request) {
	// Basic fraud check implementation
	var request struct {
		Amount   float64 `json:"amount"`
		Currency string  `json:"currency"`
		UserID   string  `json:"user_id"`
		CardHash string  `json:"card_hash"`
	}
	
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		http.Error(w, `{"error":"Invalid request format"}`, http.StatusBadRequest)
		return
	}
	
	// Perform fraud checks using Redis
	ctx := context.Background()
	
	// Check velocity - number of transactions in last hour
	velocityKey := fmt.Sprintf("velocity:%s:%s", request.UserID, time.Now().Format("2006-01-02:15"))
	velocity, _ := g.redisClient.Incr(ctx, velocityKey).Result()
	g.redisClient.Expire(ctx, velocityKey, time.Hour)
	
	// Risk scoring
	riskScore := 0
	reasons := []string{}
	
	if request.Amount > 10000 {
		riskScore += 30
		reasons = append(reasons, "High amount transaction")
	}
	
	if velocity > 5 {
		riskScore += 50
		reasons = append(reasons, "High velocity detected")
	}
	
	if request.Currency != "USD" {
		riskScore += 10
		reasons = append(reasons, "Foreign currency")
	}
	
	status := "approved"
	if riskScore > 70 {
		status = "denied"
	} else if riskScore > 30 {
		status = "review"
	}
	
	response := map[string]interface{}{
		"status":      status,
		"risk_score":  riskScore,
		"reasons":     reasons,
		"request_id":  generateRequestID(),
		"timestamp":   time.Now().UTC(),
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (g *Gateway) fraudReportHandler(w http.ResponseWriter, r *http.Request) {
	// Handle fraud reporting
	var report struct {
		TransactionID string `json:"transaction_id"`
		ReportType    string `json:"report_type"`
		Description   string `json:"description"`
		UserID        string `json:"user_id"`
	}
	
	if err := json.NewDecoder(r.Body).Decode(&report); err != nil {
		http.Error(w, `{"error":"Invalid request format"}`, http.StatusBadRequest)
		return
	}
	
	// Store fraud report in Redis for processing
	reportKey := fmt.Sprintf("fraud_report:%s", generateRequestID())
	reportData, _ := json.Marshal(report)
	
	ctx := context.Background()
	g.redisClient.Set(ctx, reportKey, reportData, 24*time.Hour)
	
	// Log for monitoring
	log.Printf("Fraud report received: %+v", report)
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":    "received",
		"report_id": reportKey,
	})
}

// Utility functions

func (g *Gateway) getRateLimiter(clientIP string) *rate.Limiter {
	if limiter, exists := g.rateLimiters[clientIP]; exists {
		return limiter
	}
	
	// Create new rate limiter: requests per minute
	limiter := rate.NewLimiter(rate.Every(time.Minute/time.Duration(g.config.RateLimitRPM)), g.config.RateLimitRPM)
	g.rateLimiters[clientIP] = limiter
	return limiter
}

func (g *Gateway) validateJWT(token string) bool {
	// Basic JWT validation - in production use proper JWT library
	return token != "" && len(token) > 10
}

func (g *Gateway) extractUserFromJWT(token string) string {
	// Extract user ID from JWT - simplified implementation
	return "user-" + token[:8]
}

func (g *Gateway) checkServiceHealth(service *ServiceProxy) string {
	resp, err := service.Client.Get(service.URL + "/health")
	if err != nil {
		return "unhealthy"
	}
	defer resp.Body.Close()
	
	if resp.StatusCode == http.StatusOK {
		return "healthy"
	}
	return "unhealthy"
}

func (g *Gateway) checkRedisHealth() string {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	
	if err := g.redisClient.Ping(ctx).Err(); err != nil {
		return "unhealthy"
	}
	return "healthy"
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header first
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		return strings.Split(xff, ",")[0]
	}
	
	// Check X-Real-IP header
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return xri
	}
	
	// Fall back to remote address
	return strings.Split(r.RemoteAddr, ":")[0]
}

func generateRequestID() string {
	return fmt.Sprintf("%d", time.Now().UnixNano())
}

// Circuit Breaker implementation

func (cb *CircuitBreaker) canExecute() bool {
	switch cb.state {
	case "closed":
		return true
	case "open":
		if time.Since(cb.lastFailTime) > cb.timeout {
			cb.state = "half-open"
			return true
		}
		return false
	case "half-open":
		return true
	default:
		return false
	}
}

func (cb *CircuitBreaker) recordSuccess() {
	cb.successCount++
	if cb.state == "half-open" && cb.successCount >= 3 {
		cb.state = "closed"
		cb.failureCount = 0
		cb.successCount = 0
	}
}

func (cb *CircuitBreaker) recordFailure() {
	cb.failureCount++
	cb.lastFailTime = time.Now()
	
	if cb.failureCount >= cb.failureThreshold {
		cb.state = "open"
	}
}

// Response writer wrapper to capture status codes

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}