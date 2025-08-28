package com.trading.payments.service;

import com.trading.payments.dto.PaymentResponse;
import com.trading.payments.dto.FraudAlert;
import com.trading.payments.dto.TransactionEvent;
import com.trading.payments.entity.AlertLevel;
import com.trading.payments.entity.DailyPosition;
import com.trading.payments.entity.RiskAlert;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentEventService {
    
    private final SimpMessagingTemplate messagingTemplate;
    
    // In-memory stats for real-time dashboard
    private final Map<String, Long> merchantTransactionCounts = new ConcurrentHashMap<>();
    private final Map<String, Long> fraudAlertCounts = new ConcurrentHashMap<>();
    
    /**
     * Broadcast transaction events to WebSocket subscribers
     */
    public void broadcastTransactionEvent(PaymentResponse payment) {
        try {
            TransactionEvent event = TransactionEvent.builder()
                .transactionId(payment.getTransactionId())
                .merchantId("DEMO_MERCHANT") // Simplified for demo
                .amount(payment.getAmount())
                .status(payment.getStatus())
                .fraudScore(payment.getFraudScore())
                .timestamp(payment.getProcessedAt())
                .build();
            
            // Update real-time counters
            updateMerchantStats("DEMO_MERCHANT");
            
            // Broadcast to all subscribers listening to /topic/transactions
            messagingTemplate.convertAndSend("/topic/transactions", event);
            
            // Also send to live feed (trading-style data feed)
            sendTransactionFeed(payment);
            
            log.debug("Broadcasted transaction event: {}", event.getTransactionId());
            
        } catch (Exception e) {
            log.error("Failed to broadcast transaction event: ", e);
        }
    }
    
    /**
     * Send fraud alerts to monitoring dashboard
     */
    public void sendFraudAlert(PaymentResponse payment) {
        if (payment.getFraudScore() == null || payment.getFraudScore() <= 50) {
            return; // Only send alerts for high-risk transactions
        }
        
        try {
            FraudAlert alert = FraudAlert.builder()
                .transactionId(payment.getTransactionId())
                .merchantId("DEMO_MERCHANT")
                .amount(payment.getAmount())
                .fraudScore(payment.getFraudScore())
                .riskLevel(determineRiskLevel(payment.getFraudScore()))
                .message(payment.getMessage())
                .timestamp(Instant.now())
                .build();
            
            // Update fraud alert counters
            updateFraudStats("DEMO_MERCHANT");
            
            // Send to different topics based on severity
            messagingTemplate.convertAndSend("/topic/fraud-alerts", alert);
            
            // Send critical alerts to admin channel
            if (payment.getFraudScore() > 75) {
                messagingTemplate.convertAndSend("/topic/admin/critical-fraud", alert);
            }
            
            log.warn("Fraud alert sent: {} - Score: {}", alert.getTransactionId(), alert.getFraudScore());
            
        } catch (Exception e) {
            log.error("Failed to send fraud alert: ", e);
        }
    }
    
    /**
     * Send live transaction feed (like market data feed)
     */
    public void sendTransactionFeed(PaymentResponse payment) {
        try {
            // Create trading-style data feed format
            Map<String, Object> feedData = Map.of(
                "type", "PAYMENT_TICK",
                "symbol", "PAY_" + payment.getTransactionId().substring(4, 8), // Create ticker-like symbol
                "price", payment.getAmount(),
                "status", payment.getStatus(),
                "volume", 1,
                "risk", payment.getFraudScore(),
                "timestamp", payment.getProcessedAt().toEpochMilli()
            );
            
            // Send to live feed subscribers (simulates market data feed)
            messagingTemplate.convertAndSend("/topic/feed/live", feedData);
            
            // Send merchant-specific feed
            messagingTemplate.convertAndSend("/topic/feed/merchant/DEMO_MERCHANT", feedData);
            
        } catch (Exception e) {
            log.error("Failed to send transaction feed: ", e);
        }
    }
    
    /**
     * Broadcast real-time dashboard statistics
     */
    public void broadcastDashboardStats() {
        try {
            Map<String, Object> stats = Map.of(
                "type", "DASHBOARD_STATS",
                "totalTransactions", merchantTransactionCounts.values().stream().mapToLong(Long::longValue).sum(),
                "merchantStats", merchantTransactionCounts,
                "fraudAlerts", fraudAlertCounts.values().stream().mapToLong(Long::longValue).sum(),
                "fraudByMerchant", fraudAlertCounts,
                "timestamp", Instant.now()
            );
            
            messagingTemplate.convertAndSend("/topic/dashboard/stats", stats);
            
        } catch (Exception e) {
            log.error("Failed to broadcast dashboard stats: ", e);
        }
    }
    
    /**
     * Send personal notifications to specific users
     */
    public void sendPersonalAlert(String userId, PaymentResponse payment) {
        try {
            Map<String, Object> personalAlert = Map.of(
                "type", "PERSONAL_ALERT",
                "message", "High-value transaction processed for your merchant",
                "transactionId", payment.getTransactionId(),
                "amount", payment.getAmount(),
                "timestamp", Instant.now()
            );
            
            // This goes only to the specific user
            messagingTemplate.convertAndSendToUser(userId, "/queue/personal", personalAlert);
            
        } catch (Exception e) {
            log.error("Failed to send personal alert: ", e);
        }
    }
    
    private String determineRiskLevel(Integer fraudScore) {
        if (fraudScore == null) return "UNKNOWN";
        if (fraudScore <= 20) return "LOW";
        if (fraudScore <= 50) return "MEDIUM";
        if (fraudScore <= 75) return "HIGH";
        return "CRITICAL";
    }
    
    private void updateMerchantStats(String merchantId) {
        merchantTransactionCounts.merge(merchantId, 1L, Long::sum);
    }
    
    /**
     * Broadcast position updates (like portfolio rebalancing alerts)
     */
    public void broadcastPositionUpdate(DailyPosition position) {
        try {
            Map<String, Object> positionUpdate = Map.of(
                "type", "POSITION_UPDATE",
                "merchantId", position.getMerchantId(),
                "totalVolume", position.getTotalVolume(),
                "transactionCount", position.getTransactionCount(),
                "riskExposure", position.getRiskExposurePercent(),
                "approvalRate", position.getApprovedCount() > 0 ? 
                    position.getApprovedVolume().divide(position.getTotalVolume(), 4, java.math.RoundingMode.HALF_UP) : 
                    java.math.BigDecimal.ZERO,
                "timestamp", Instant.now()
            );
            
            // Send to risk monitoring dashboard
            messagingTemplate.convertAndSend("/topic/risk/positions", positionUpdate);
            
            // Send to merchant-specific channel
            messagingTemplate.convertAndSend("/topic/risk/merchant/" + position.getMerchantId(), positionUpdate);
            
            log.debug("Position update broadcast: {} - Volume: {}", 
                position.getMerchantId(), position.getTotalVolume());
                
        } catch (Exception e) {
            log.error("Failed to broadcast position update: ", e);
        }
    }
    
    /**
     * Broadcast risk alerts (limit violations, etc.)
     */
    public void broadcastRiskAlert(RiskAlert alert) {
        try {
            Map<String, Object> riskAlert = Map.of(
                "type", "RISK_ALERT",
                "merchantId", alert.getMerchantId(),
                "alertType", alert.getAlertType().toString(),
                "alertLevel", alert.getAlertLevel().toString(),
                "message", alert.getMessage(),
                "thresholdValue", alert.getThresholdValue() != null ? alert.getThresholdValue() : 0,
                "currentValue", alert.getCurrentValue() != null ? alert.getCurrentValue() : 0,
                "transactionId", alert.getTransactionId(),
                "timestamp", alert.getCreatedAt()
            );
            
            // Send to risk management dashboard
            messagingTemplate.convertAndSend("/topic/risk/alerts", riskAlert);
            
            // Send critical alerts to admin channel
            if (alert.getAlertLevel() == AlertLevel.CRITICAL || alert.getAlertLevel() == AlertLevel.EMERGENCY) {
                messagingTemplate.convertAndSend("/topic/admin/critical", riskAlert);
            }
            
            log.warn("Risk alert broadcast: {} - {} - {}", 
                alert.getMerchantId(), alert.getAlertType(), alert.getMessage());
                
        } catch (Exception e) {
            log.error("Failed to broadcast risk alert: ", e);
        }
    }

    private void updateFraudStats(String merchantId) {
        fraudAlertCounts.merge(merchantId, 1L, Long::sum);
    }
}