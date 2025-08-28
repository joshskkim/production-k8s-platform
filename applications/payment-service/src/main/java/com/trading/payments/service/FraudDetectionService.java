package com.trading.payments.service;

import com.trading.payments.dto.FraudResult;
import com.trading.payments.dto.PaymentRequest;
import com.trading.payments.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.codec.digest.DigestUtils;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;

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
        return DigestUtils.sha256Hex(cardNumber + "SALT_KEY");
    }
    
    private String buildReason(int score) {
        if (score <= 20) return "Low risk transaction";
        if (score <= 50) return "Medium risk - approved with monitoring";
        return "High risk - transaction declined";
    }
}
