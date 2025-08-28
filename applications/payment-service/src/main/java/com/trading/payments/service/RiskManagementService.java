package com.trading.payments.service;

import com.trading.payments.entity.*;
import com.trading.payments.repository.*;
import com.trading.payments.dto.PaymentRequest;
import com.trading.payments.dto.RiskAssessment;
import com.trading.payments.dto.PositionSummary;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class RiskManagementService {
    
    private final MerchantRiskProfileRepository riskProfileRepository;
    private final DailyPositionRepository dailyPositionRepository;
    private final RiskAlertRepository riskAlertRepository;
    private final TransactionRepository transactionRepository;
    private final PaymentEventService eventService;
    
    /**
     * Pre-transaction risk assessment - called before processing payment
     */
    public RiskAssessment assessTransactionRisk(PaymentRequest request) {
        String merchantId = request.getMerchantId();
        BigDecimal amount = request.getAmount();
        
        // Get merchant risk profile
        Optional<MerchantRiskProfile> profile = riskProfileRepository.findByMerchantId(merchantId);
        if (profile.isEmpty()) {
            return createDefaultRiskAssessment(merchantId, amount, "No risk profile found");
        }
        
        MerchantRiskProfile riskProfile = profile.get();
        
        // Check single transaction limit
        if (amount.compareTo(riskProfile.getMaxSingleTransaction()) > 0) {
            createRiskAlert(merchantId, AlertType.SINGLE_TRANSACTION_LARGE, AlertLevel.CRITICAL,
                riskProfile.getMaxSingleTransaction(), amount, 
                "Transaction exceeds single transaction limit", request.getCardNumber());
            return RiskAssessment.blocked("Transaction exceeds single transaction limit of $" + 
                riskProfile.getMaxSingleTransaction());
        }
        
        // Get current daily position
        DailyPosition todayPosition = getCurrentDailyPosition(merchantId);
        
        // Check daily limits
        BigDecimal projectedDailyVolume = todayPosition.getTotalVolume().add(amount);
        if (projectedDailyVolume.compareTo(riskProfile.getDailyLimit()) > 0) {
            createRiskAlert(merchantId, AlertType.DAILY_LIMIT_EXCEEDED, AlertLevel.CRITICAL,
                riskProfile.getDailyLimit(), projectedDailyVolume,
                "Daily limit exceeded", null);
            return RiskAssessment.blocked("Daily limit of $" + riskProfile.getDailyLimit() + " would be exceeded");
        }
        
        // Check daily transaction count
        if (todayPosition.getTransactionCount() >= riskProfile.getTransactionCountLimit()) {
            createRiskAlert(merchantId, AlertType.TRANSACTION_COUNT_HIGH, AlertLevel.WARNING,
                BigDecimal.valueOf(riskProfile.getTransactionCountLimit()), 
                BigDecimal.valueOf(todayPosition.getTransactionCount()),
                "Daily transaction count limit reached", null);
            return RiskAssessment.blocked("Daily transaction count limit reached");
        }
        
        // Check if approaching limits (80% threshold)
        BigDecimal dailyThreshold = riskProfile.getDailyLimit().multiply(BigDecimal.valueOf(0.8));
        if (projectedDailyVolume.compareTo(dailyThreshold) > 0) {
            createRiskAlert(merchantId, AlertType.DAILY_LIMIT_APPROACHED, AlertLevel.WARNING,
                riskProfile.getDailyLimit(), projectedDailyVolume,
                "Approaching daily limit (80% threshold)", null);
        }
        
        // Calculate risk exposure percentage
        BigDecimal exposurePercent = projectedDailyVolume
            .divide(riskProfile.getDailyLimit(), 4, RoundingMode.HALF_UP)
            .multiply(BigDecimal.valueOf(100));
        
        return RiskAssessment.approved(
            "Transaction approved - " + exposurePercent.setScale(1, RoundingMode.HALF_UP) + "% of daily limit",
            exposurePercent.intValue()
        );
    }
    
    /**
     * Post-transaction position update - called after successful transaction
     */
    @Transactional
    public void updatePosition(String merchantId, Transaction transaction) {
        try {
            DailyPosition position = getCurrentDailyPosition(merchantId);
            
            // Update position metrics
            position.setTotalVolume(position.getTotalVolume().add(transaction.getAmount()));
            position.setTransactionCount(position.getTransactionCount() + 1);
            
            if ("approved".equals(transaction.getStatus())) {
                position.setApprovedVolume(position.getApprovedVolume().add(transaction.getAmount()));
                position.setApprovedCount(position.getApprovedCount() + 1);
            } else {
                position.setDeclinedVolume(position.getDeclinedVolume().add(transaction.getAmount()));
                position.setDeclinedCount(position.getDeclinedCount() + 1);
            }
            
            // Update max single transaction
            if (transaction.getAmount().compareTo(position.getMaxSingleTransaction()) > 0) {
                position.setMaxSingleTransaction(transaction.getAmount());
            }
            
            // Calculate average fraud score
            BigDecimal avgFraudScore = calculateAverageFraudScore(merchantId);
            position.setAvgFraudScore(avgFraudScore);
            
            // Calculate risk exposure
            Optional<MerchantRiskProfile> profile = riskProfileRepository.findByMerchantId(merchantId);
            if (profile.isPresent()) {
                BigDecimal exposurePercent = position.getTotalVolume()
                    .divide(profile.get().getDailyLimit(), 4, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100));
                position.setRiskExposurePercent(exposurePercent);
            }
            
            // Save updated position
            dailyPositionRepository.save(position);
            
            // Broadcast position update via WebSocket
            eventService.broadcastPositionUpdate(position);
            
            log.debug("Updated position for {}: volume=${}, count={}, exposure={}%", 
                merchantId, position.getTotalVolume(), position.getTransactionCount(), 
                position.getRiskExposurePercent());
                
        } catch (Exception e) {
            log.error("Failed to update position for merchant {}: ", merchantId, e);
        }
    }
    
    /**
     * Get current daily position for merchant
     */
    public DailyPosition getCurrentDailyPosition(String merchantId) {
        return dailyPositionRepository.findByMerchantIdAndPositionDate(merchantId, LocalDate.now())
            .orElseGet(() -> createNewDailyPosition(merchantId));
    }
    
    /**
     * Get position summary across all merchants
     */
    public PositionSummary getPortfolioSummary() {
        List<DailyPosition> positions = dailyPositionRepository.findByPositionDate(LocalDate.now());
        
        BigDecimal totalVolume = positions.stream()
            .map(DailyPosition::getTotalVolume)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
            
        Integer totalCount = positions.stream()
            .map(DailyPosition::getTransactionCount)
            .reduce(0, Integer::sum);
            
        BigDecimal totalApproved = positions.stream()
            .map(DailyPosition::getApprovedVolume)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
            
        // Count unresolved risk alerts
        Long activeAlerts = riskAlertRepository.countByIsResolvedFalseAndCreatedAtAfter(
            LocalDateTime.now().withHour(0).withMinute(0).withSecond(0)
        );
        
        return PositionSummary.builder()
            .totalVolume(totalVolume)
            .totalTransactions(totalCount)
            .approvedVolume(totalApproved)
            .approvalRate(totalCount > 0 ? totalApproved.divide(totalVolume, 4, RoundingMode.HALF_UP) : BigDecimal.ZERO)
            .activeAlerts(activeAlerts.intValue())
            .merchantCount(positions.size())
            .timestamp(LocalDateTime.now())
            .build();
    }
    
    private DailyPosition createNewDailyPosition(String merchantId) {
        DailyPosition position = DailyPosition.builder()
            .merchantId(merchantId)
            .positionDate(LocalDate.now())
            .totalVolume(BigDecimal.ZERO)
            .transactionCount(0)
            .approvedVolume(BigDecimal.ZERO)
            .approvedCount(0)
            .declinedVolume(BigDecimal.ZERO)
            .declinedCount(0)
            .avgFraudScore(BigDecimal.ZERO)
            .maxSingleTransaction(BigDecimal.ZERO)
            .riskExposurePercent(BigDecimal.ZERO)
            .build();
            
        return dailyPositionRepository.save(position);
    }
    
    private void createRiskAlert(String merchantId, AlertType alertType, AlertLevel alertLevel,
                                BigDecimal threshold, BigDecimal current, String message, String transactionId) {
        try {
            RiskAlert alert = RiskAlert.builder()
                .merchantId(merchantId)
                .alertType(alertType)
                .alertLevel(alertLevel)
                .thresholdValue(threshold)
                .currentValue(current)
                .message(message)
                .transactionId(transactionId)
                .isResolved(false)
                .build();
                
            riskAlertRepository.save(alert);
            
            // Broadcast alert via WebSocket
            eventService.broadcastRiskAlert(alert);
            
            log.warn("Risk alert created: {} - {} - {}", merchantId, alertType, message);
            
        } catch (Exception e) {
            log.error("Failed to create risk alert: ", e);
        }
    }
    
    private BigDecimal calculateAverageFraudScore(String merchantId) {
        Double avgScore = transactionRepository.averageFraudScoreByMerchantSince(
            merchantId, LocalDateTime.now().withHour(0).withMinute(0).withSecond(0)
        );
        return avgScore != null ? BigDecimal.valueOf(avgScore).setScale(2, RoundingMode.HALF_UP) : BigDecimal.ZERO;
    }
    
    private RiskAssessment createDefaultRiskAssessment(String merchantId, BigDecimal amount, String reason) {
        // Default limits for unknown merchants
        if (amount.compareTo(BigDecimal.valueOf(5000)) > 0) {
            return RiskAssessment.blocked("Amount exceeds default limit for unregistered merchant");
        }
        return RiskAssessment.approved(reason, 10);
    }
}