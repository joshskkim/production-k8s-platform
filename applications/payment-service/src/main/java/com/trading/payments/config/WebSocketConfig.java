package com.trading.payments.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // Enable simple in-memory broker for destinations prefixed with "/topic" and "/queue"
        config.enableSimpleBroker("/topic", "/queue");
        
        // Set application destination prefix for messages from clients to server
        config.setApplicationDestinationPrefixes("/app");
        
        // Set user destination prefix for private user messages
        config.setUserDestinationPrefix("/user");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // Register STOMP endpoint that clients will connect to
        registry.addEndpoint("/ws/payments")
                .setAllowedOriginPatterns("*")  // For development - restrict in production
                .withSockJS();  // Enable SockJS fallback for older browsers
                
        // Raw WebSocket endpoint (no SockJS) for better performance
        registry.addEndpoint("/ws/payments-raw")
                .setAllowedOriginPatterns("*");
    }
}
