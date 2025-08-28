// Save as: apps/payment-service/src/main/java/com/trading/payments/service/PaymentService.java

package com.trading.payments.service;

import com.trading.payments.entity.Transaction;
import com.trading.payments.repository.TransactionRepository;
import com.trading.payments.dto.MerchantSummary;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentService {
    
    private final TransactionRepository transactionRepository;
    
    @Transactional
    public Transaction saveTransaction(Transaction transaction) {
        log.info("Saving transaction: {}", transaction.getTransactionId());
        return transactionRepository.save(transaction);
    }
    
    public Optional<Transaction> findByTransactionId(String transactionId) {
        return transactionRepository.findByTransactionId(transactionId);
    }
    
    public MerchantSummary getMerchantSummary(String merchantId, int hours) {
        LocalDateTime since = LocalDateTime.now().minusHours(hours);
        
        Long totalTransactions = transactionRepository.countTransactionsByMerchantSince(merchantId, since);
        BigDecimal totalAmount = transactionRepository.sumApprovedAmountByMerchantSince(merchantId, since);
        
        // Count approved vs declined
        var transactions = transactionRepository.findByMerchantIdAndCreatedAtAfter(merchantId, since);
        long approvedCount = transactions.stream()
            .filter(t -> "approved".equals(t.getStatus()))
            .count();
        long declinedCount = totalTransactions - approvedCount;
        
        double approvalRate = totalTransactions > 0 ? 
            (double) approvedCount / totalTransactions * 100 : 0.0;
            
        Double averageFraudScore = transactionRepository
            .averageFraudScoreByMerchantSince(merchantId, since);
        
        return MerchantSummary.builder()
            .merchantId(merchantId)
            .totalTransactions(totalTransactions)
            .totalAmount(totalAmount != null ? totalAmount : BigDecimal.ZERO)
            .approvedCount(approvedCount)
            .declinedCount(declinedCount)
            .approvalRate(Math.round(approvalRate * 100.0) / 100.0)
            .averageFraudScore(averageFraudScore != null ? averageFraudScore : 0.0)
            .build();
    }
}

// Fraud Detection Service (Phase 2 preview)
@Service
@RequiredArgsConstructor
@Slf4j
public class FraudDetectionService {
    
    private final TransactionRepository transactionRepository;
    
    public FraudResult evaluateTransaction(PaymentRequest request) {
        int riskScore = 0;
        
        // Rule 1: High amount check
        if (request.getAmount().compareTo(BigDecimal.valueOf(1000)) > 0) {
            riskScore += 25;
            log.debug("High amount detected: {}", request.getAmount());
        }
        
        // Rule 2: Suspicious round amounts
        if (request.getAmount().remainder(BigDecimal.valueOf(1000)).equals(BigDecimal.ZERO) &&
            request.getAmount().compareTo(BigDecimal.valueOf(5000)) > 0) {
            riskScore += 30;
            log.debug("Suspicious round amount: {}", request.getAmount());
        }
        
        // Rule 3: High-risk merchant
        if ("MERCHANT_003".equals(request.getMerchantId())) { // Crypto exchange
            riskScore += 15;
            log.debug("High-risk merchant: {}", request.getMerchantId());
        }
        
        // Rule 4: Velocity check (simple version)
        String cardHash = hashCardNumber(request.getCardNumber());
        Long recentTransactions = transactionRepository
            .countTransactionsByCardSince(cardHash, LocalDateTime.now().minusHours(1));
        
        if (recentTransactions != null && recentTransactions >= 5) {
            riskScore += 20;
            log.debug("High velocity detected: {} transactions in 1 hour", recentTransactions);
        }
        
        // Cap at 100
        riskScore = Math.min(riskScore, 100);
        
        return FraudResult.builder()
            .riskScore(riskScore)
            .approved(riskScore <= 50)
            .reason(buildReason(riskScore))
            .build();
    }
    
    private String hashCardNumber(String cardNumber) {
        return org.apache.commons.codec.digest.DigestUtils.sha256Hex(cardNumber + "SALT_KEY");
    }
    
    private String buildReason(int score) {
        if (score <= 20) return "Low risk transaction";
        if (score <= 50) return "Medium risk - approved with monitoring";
        return "High risk - transaction declined";
    }
}

// Supporting DTOs
@lombok.Data
@lombok.Builder
@lombok.NoArgsConstructor
@lombok.AllArgsConstructor
class FraudResult {
    private Integer riskScore;
    private Boolean approved;
    private String reason;
}