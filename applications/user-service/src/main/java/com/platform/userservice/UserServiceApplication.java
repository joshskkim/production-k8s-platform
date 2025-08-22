package com.platform.userservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.HashMap;
import java.util.Map;
import java.time.LocalDateTime;

@SpringBootApplication
public class UserServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(UserServiceApplication.class, args);
    }
}

@RestController
class HealthController {
    
    @GetMapping("/actuator/health")
    public Map<String, Object> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("timestamp", LocalDateTime.now());
        response.put("service", "user-service");
        response.put("version", "1.0.0");
        return response;
    }
    
    @GetMapping("/actuator/health/readiness")
    public Map<String, Object> readiness() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("timestamp", LocalDateTime.now());
        return response;
    }
    
    @GetMapping("/api/users")
    public Map<String, Object> getUsers() {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "User service is running");
        response.put("timestamp", LocalDateTime.now());
        response.put("users", new String[]{"demo-user-1", "demo-user-2"});
        return response;
    }
}