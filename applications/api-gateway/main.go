package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
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

	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/redis/go-redis/v9"
	"github.com/rs/cors"
	"golang.org/x/crypto/bcrypt"
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
	Port                    string
	PaymentServiceURL       string
	RedisURL                string
	JWTSecret               []byte
	AdminKey                string
	RateLimitRPM            int
	CircuitBreakerThreshold int
	LogLevel                string
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
	failureCount     int
	successCount     int
	failureThreshold int
	timeout          time.Duration
	lastFailTime     time.Time
	state            string // "closed", "open", "half-open"
}

// Custom claims for JWT
type Claims struct {
	UserID string   `json:"user_id"`
	Roles  []string `json:"roles"`
	jwt.RegisteredClaims
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

	securityEvents = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "api_gateway_security_events_total",
			Help: "Total number of security events",
		},
		[]string{"event_type", "client_ip"},
	)
)

var startTime time.Time

func init() {
	startTime = time.Now()
	// Register Prometheus metrics
	prometheus.MustRegister(requestsTotal)
	prometheus.MustRegister(requestDuration)
	prometheus.MustRegister(rateLimitHits)
	prometheus.MustRegister(circuitBreakerState)
	prometheus.MustRegister(securityEvents)
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
		Addr:         ":" + config.Port,
		Handler:      gateway.router,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
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
	jwtSecret := getEnv("JWT_SECRET", "")
	if jwtSecret == "" {
		log.Println("⚠️  JWT_SECRET not set, generating secure secret")
		jwtSecret = generateSecureSecret()
	}

	adminKey := getEnv("ADMIN_KEY", "")
	if adminKey == "" {
		log.Println("⚠️  ADMIN_KEY not set, generating secure key")
		adminKey = generateSecureSecret()
		log.Printf("Generated ADMIN_KEY: %s", adminKey)
	}

	return &Config{
		Port:                    getEnv("PORT", "8080"),
		PaymentServiceURL:       getEnv("PAYMENT_SERVICE_URL", "http://payment-service:8080"),
		RedisURL:                getEnv("REDIS_URL", "redis:6379"),
		JWTSecret:               []byte(jwtSecret),
		AdminKey:                adminKey,
		RateLimitRPM:            getEnvInt("RATE_LIMIT_RPM", 100),
		CircuitBreakerThreshold: getEnvInt("CIRCUIT_BREAKER_THRESHOLD", 5),
		LogLevel:                getEnv("LOG_LEVEL", "INFO"),
	}
}

func (g *Gateway) initRedis() {
	g.redisClient = redis.NewClient(&redis.Options{
		Addr:         g.config.RedisURL,
		DB:           0,
		MaxRetries:   3,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
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
		timeout:          60 * time.Second,
		state:            "closed",
	}
}

func (g *Gateway) setupRoutes() {
	g.router = mux.NewRouter()

	// Security headers middleware
	g.router.Use(g.securityHeadersMiddleware)

	// CORS configuration
	c := cors.New(cors.Options{
		AllowedOrigins:   getEnvList("CORS_ALLOWED_ORIGINS", []string{"http://localhost:3000"}),
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Content-Type", "Authorization", "X-Requested-With"},
		AllowCredentials: true,
		MaxAge:           86400,
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

	// Admin routes
	adminRoutes := v1.PathPrefix("/admin").Subrouter()
	adminRoutes.Use(g.adminAuthMiddleware)
	adminRoutes.HandleFunc("/stats", g.statsHandler).Methods("GET")
	adminRoutes.HandleFunc("/circuit-breaker/{service}", g.circuitBreakerHandler).Methods("GET", "POST")
	adminRoutes.HandleFunc("/rate-limits", g.rateLimitsHandler).Methods("GET")
}

// Middleware implementations

func (g *Gateway) securityHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Security headers
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		w.Header().Set("Content-Security-Policy", "default-src 'self'")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")

		next.ServeHTTP(w, r)
	})
}

func (g *Gateway) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Create a response writer that captures the status code
		rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(rw, r)

		// Sanitize logging - don't log sensitive data
		uri := r.RequestURI
		if strings.Contains(uri, "password") || strings.Contains(uri, "token") {
			uri = "[REDACTED]"
		}

		log.Printf("[%s] %s %s %d %v",
			r.Method,
			uri,
			getClientIP(r),
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
			sanitizePath(r.URL.Path),
			strconv.Itoa(rw.statusCode),
			"gateway",
		).Inc()

		requestDuration.WithLabelValues(
			r.Method,
			sanitizePath(r.URL.Path),
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
			rateLimitHits.WithLabelValues(clientIP, sanitizePath(r.URL.Path)).Inc()
			securityEvents.WithLabelValues("rate_limit_exceeded", clientIP).Inc()

			w.Header().Set("X-RateLimit-Limit", strconv.Itoa(g.config.RateLimitRPM))
			w.Header().Set("X-RateLimit-Remaining", "0")
			w.Header().Set("Retry-After", "60")

			http.Error(w, `{"error":"Rate limit exceeded"}`, http.StatusTooManyRequests)
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
			securityEvents.WithLabelValues("missing_auth_header", getClientIP(r)).Inc()
			http.Error(w, `{"error":"Authorization required"}`, http.StatusUnauthorized)
			return
		}

		token := strings.TrimPrefix(authHeader, "Bearer ")
		claims, err := g.validateJWT(token)
		if err != nil {
			securityEvents.WithLabelValues("invalid_jwt", getClientIP(r)).Inc()
			http.Error(w, `{"error":"Invalid token"}`, http.StatusUnauthorized)
			return
		}

		// Add user context to request
		r.Header.Set("X-User-ID", claims.UserID)
		next.ServeHTTP(w, r)
	})
}

func (g *Gateway) adminAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		adminKey := r.Header.Get("X-Admin-Key")

		// Use bcrypt to compare admin key
		if err := bcrypt.CompareHashAndPassword([]byte(g.config.AdminKey), []byte(adminKey)); err != nil {
			securityEvents.WithLabelValues("invalid_admin_key", getClientIP(r)).Inc()
			http.Error(w, `{"error":"Admin access denied"}`, http.StatusForbidden)
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
			"redis":           g.checkRedisHealth(),
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
		http.Error(w, `{"error":"Service temporarily unavailable"}`, http.StatusServiceUnavailable)
		return
	}

	// Forward request to payment service
	targetURL := g.paymentService.URL + r.URL.Path
	if r.URL.RawQuery != "" {
		targetURL += "?" + r.URL.RawQuery
	}

	proxyReq, err := http.NewRequestWithContext(r.Context(), r.Method, targetURL, r.Body)
	if err != nil {
		cb.recordFailure()
		http.Error(w, `{"error":"Request processing failed"}`, http.StatusInternalServerError)
		return
	}

	// Copy safe headers only
	safeHeaders := []string{"Content-Type", "Accept", "User-Agent", "X-User-ID"}
	for _, header := range safeHeaders {
		if value := r.Header.Get(header); value != "" {
			proxyReq.Header.Set(header, value)
		}
	}

	// Add request ID for tracing
	requestID := generateSecureRequestID()
	proxyReq.Header.Set("X-Request-ID", requestID)
	w.Header().Set("X-Request-ID", requestID)

	resp, err := g.paymentService.Client.Do(proxyReq)
	if err != nil {
		cb.recordFailure()
		log.Printf("Payment service error: %v", err)
		http.Error(w, `{"error":"Service unavailable"}`, http.StatusServiceUnavailable)
		return
	}
	defer resp.Body.Close()

	cb.recordSuccess()

	// Copy response headers (safe ones only)
	safeResponseHeaders := []string{"Content-Type", "Content-Length", "X-Request-ID"}
	for _, header := range safeResponseHeaders {
		if value := resp.Header.Get(header); value != "" {
			w.Header().Set(header, value)
		}
	}

	w.WriteHeader(resp.StatusCode)

	// Copy body with size limit
	const maxResponseSize = 10 * 1024 * 1024 // 10MB limit
	limitedReader := http.MaxBytesReader(w, resp.Body, maxResponseSize)

	buf := make([]byte, 32*1024)
	for {
		n, err := limitedReader.Read(buf)
		if n > 0 {
			w.Write(buf[:n])
		}
		if err != nil {
			break
		}
	}
}

func (g *Gateway) fraudCheckHandler(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Amount   float64 `json:"amount"`
		Currency string  `json:"currency"`
		UserID   string  `json:"user_id"`
		CardHash string  `json:"card_hash"`
	}

	// Limit request size
	r.Body = http.MaxBytesReader(w, r.Body, 1024*1024) // 1MB limit

	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		http.Error(w, `{"error":"Invalid request"}`, http.StatusBadRequest)
		return
	}

	// Input validation
	if request.Amount <= 0 || request.Amount > 1000000 {
		http.Error(w, `{"error":"Invalid amount"}`, http.StatusBadRequest)
		return
	}

	if request.UserID == "" || len(request.UserID) > 50 {
		http.Error(w, `{"error":"Invalid user ID"}`, http.StatusBadRequest)
		return
	}

	// Perform fraud checks using Redis
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

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
		"status":     status,
		"risk_score": riskScore,
		"reasons":    reasons,
		"request_id": generateSecureRequestID(),
		"timestamp":  time.Now().UTC(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (g *Gateway) fraudReportHandler(w http.ResponseWriter, r *http.Request) {
	var report struct {
		TransactionID string `json:"transaction_id"`
		ReportType    string `json:"report_type"`
		Description   string `json:"description"`
		UserID        string `json:"user_id"`
	}

	r.Body = http.MaxBytesReader(w, r.Body, 1024*1024) // 1MB limit

	if err := json.NewDecoder(r.Body).Decode(&report); err != nil {
		http.Error(w, `{"error":"Invalid request"}`, http.StatusBadRequest)
		return
	}

	// Input validation
	if len(report.Description) > 1000 {
		http.Error(w, `{"error":"Description too long"}`, http.StatusBadRequest)
		return
	}

	// Store fraud report in Redis for processing
	reportID := generateSecureRequestID()
	reportKey := fmt.Sprintf("fraud_report:%s", reportID)
	reportData, _ := json.Marshal(map[string]interface{}{
		"transaction_id": report.TransactionID,
		"report_type":    report.ReportType,
		"description":    report.Description,
		"user_id":        report.UserID,
		"timestamp":      time.Now().UTC(),
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	g.redisClient.Set(ctx, reportKey, reportData, 24*time.Hour)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":    "received",
		"report_id": reportID,
	})
}

func (g *Gateway) statsHandler(w http.ResponseWriter, r *http.Request) {
	stats := map[string]interface{}{
		"uptime":        time.Since(startTime).String(),
		"rate_limiters": len(g.rateLimiters),
		"circuit_breakers": func() map[string]string {
			cbStates := make(map[string]string)
			for name, cb := range g.circuitBreakers {
				cbStates[name] = cb.state
			}
			return cbStates
		}(),
		"redis_connected": g.checkRedisHealth() == "healthy",
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}

func (g *Gateway) rateLimitsHandler(w http.ResponseWriter, r *http.Request) {
	type limiterInfo struct {
		ClientIP string `json:"client_ip"`
	}
	limiters := []limiterInfo{}
	for ip := range g.rateLimiters {
		limiters = append(limiters, limiterInfo{ClientIP: ip})
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"rate_limiters": limiters,
		"total":         len(limiters),
	})
}

func (g *Gateway) circuitBreakerHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	service := vars["service"]
	cb, ok := g.circuitBreakers[service]
	if !ok {
		http.Error(w, `{"error":"Service not found"}`, http.StatusNotFound)
		return
	}

	switch r.Method {
	case "GET":
		state := map[string]interface{}{
			"state":             cb.state,
			"failure_count":     cb.failureCount,
			"success_count":     cb.successCount,
			"failure_threshold": cb.failureThreshold,
			"timeout_seconds":   cb.timeout.Seconds(),
			"last_fail_time":    cb.lastFailTime,
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(state)
	case "POST":
		cb.state = "closed"
		cb.failureCount = 0
		cb.successCount = 0
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "reset"})
	default:
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
	}
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

func (g *Gateway) validateJWT(tokenString string) (*Claims, error) {
	claims := &Claims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return g.config.JWTSecret, nil
	})

	if err != nil {
		return nil, err
	}

	if !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}

	return claims, nil
}

func (g *Gateway) checkServiceHealth(service *ServiceProxy) string {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", service.URL+"/health", nil)
	if err != nil {
		return "unhealthy"
	}

	resp, err := service.Client.Do(req)
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

func generateSecureSecret() string {
	bytes := make([]byte, 32)
	rand.Read(bytes)
	return base64.URLEncoding.EncodeToString(bytes)
}

func generateSecureRequestID() string {
	bytes := make([]byte, 16)
	rand.Read(bytes)
	return base64.URLEncoding.EncodeToString(bytes)
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

func getEnvList(key string, defaultValue []string) []string {
	if value := os.Getenv(key); value != "" {
		return strings.Split(value, ",")
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

func sanitizePath(path string) string {
	// Remove sensitive path components
	if strings.Contains(path, "token") || strings.Contains(path, "password") {
		return "[REDACTED]"
	}
	return path
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
