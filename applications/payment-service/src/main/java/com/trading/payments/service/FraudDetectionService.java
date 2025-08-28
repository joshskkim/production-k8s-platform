package com.trading.payments.service;

import com.trading.payments.dto.FraudResult;
import com.trading.payments.dto.PaymentRequest;
import com.trading.payments.repository.TransactionRepository;
import com.trading.payments.repository.MerchantRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.codec.digest.DigestUtils;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.Duration;
import java.util.concurrent.TimeUnit;
import java.util.List;
import java.util.ArrayList;

@Service
@RequiredArgsConstructor
@Slf4j
public class FraudDetectionService {
    
    private final TransactionRepository transactionRepository;
    private final MerchantRepository merchantRepository;
    private final RedisTemplate<String, String> redisTemplate;
    
    public FraudResult evaluateTransaction(PaymentRequest request) {
        int riskScore = 0;
        List<String> triggeredRules = new ArrayList<>();
        
        String cardHash = hashCardNumber(request.getCardNumber());
        String merchantId = request.getMerchantId();
        BigDecimal amount = request.getAmount();
        
        // Rule 1: High amount check
        if (amount.compareTo(BigDecimal.valueOf(1000)) > 0) {
            riskScore += 25;
            triggeredRules.add("High amount transaction");
            log.debug("High amount detected: {}", amount);
        }
        
        // Rule 2: Suspicious round amounts
        if (amount.remainder(BigDecimal.valueOf(1000)).equals(BigDecimal.ZERO) &&
            amount.compareTo(BigDecimal.valueOf(5000)) > 0) {
            riskScore += 30;
            triggeredRules.add("Suspicious round amount");
            log.debug("Suspicious round amount: {}", amount);
        }
        
        // Rule 3: High-risk merchant category
        var merchant = merchantRepository.findByMerchantId(merchantId);
        if (merchant.isPresent() && merchant.get().getRiskLevel() >= 3) {
            riskScore += 15;
            triggeredRules.add("High-risk merchant");
            log.debug("High-risk merchant: {} (level {})", merchantId, merchant.get().getRiskLevel());
        }
        
        // Rule 4: Card velocity check (Redis cached)
        int cardVelocityScore = checkCardVelocity(cardHash, amount);
        riskScore += cardVelocityScore;
        if (cardVelocityScore > 0) {
            triggeredRules.add("High card velocity");
        }
        
        // Rule 5: Merchant velocity check (Redis cached)
        int merchantVelocityScore = checkMerchantVelocity(merchantId, amount);
        riskScore += merchantVelocityScore;
        if (merchantVelocityScore > 0) {
            triggeredRules.add("High merchant velocity");
        }
        
        // Rule 6: Unusual amount patterns
        int patternScore = checkAmountPatterns(cardHash, amount);
        riskScore += patternScore;
        if (patternScore > 0) {
            triggeredRules.add("Unusual amount pattern");
        }
        
        // Rule 7: Time-based risk (late night transactions)
        int timeRisk = checkTimeBasedRisk();
        riskScore += timeRisk;
        if (timeRisk > 0) {
            triggeredRules.add("Off-hours transaction");
        }
        
        // Cache this transaction for velocity checks
        cacheTransaction(cardHash, merchantId, amount);
        
        // Cap at 100
        riskScore = Math.min(riskScore, 100);
        
        return FraudResult.builder()
            .riskScore(riskScore)
            .approved(riskScore <= 50)
            .reason(buildReason(riskScore, triggeredRules))
            .build();
    }
    
    private int checkCardVelocity(String cardHash, BigDecimal amount) {
        String velocityKey = "card_velocity:" + cardHash;
        String amountKey = "card_amount:" + cardHash;
        
        try {
            // Get transaction count in last hour
            String countStr = redisTemplate.opsForValue().get(velocityKey);
            int count = countStr != null ? Integer.parseInt(countStr) : 0;
            
            // Get total amount in last hour
            String totalStr = redisTemplate.opsForValue().get(amountKey);
            BigDecimal totalAmount = totalStr != null ? new BigDecimal(totalStr) : BigDecimal.ZERO;
            
            int riskScore = 0;
            
            // Velocity rule: More than 5 transactions in 1 hour
            if (count >= 5) {
                riskScore += 20;
                log.debug("Card velocity risk: {} transactions in 1 hour", count);
            }
            
            // Amount velocity: More than $5000 in 1 hour
            if (totalAmount.add(amount).compareTo(BigDecimal.valueOf(5000)) > 0) {
                riskScore += 25;
                log.debug("Card amount velocity risk: ${} in 1 hour", totalAmount.add(amount));
            }
            
            return riskScore;
            
        } catch (Exception e) {
            log.warn("Redis velocity check failed: {}", e.getMessage());
            return 0; // Fail open - don't block transactions if Redis is down
        }
    }
    
    private int checkMerchantVelocity(String merchantId, BigDecimal amount) {
        String velocityKey = "merchant_velocity:" + merchantId;
        
        try {
            String countStr = redisTemplate.opsForValue().get(velocityKey);
            int count = countStr != null ? Integer.parseInt(countStr) : 0;
            
            // High merchant transaction volume in short time
            if (count >= 50) {
                log.debug("Merchant velocity risk: {} transactions in 10 minutes", count);
                return 15;
            }
            
            return 0;
            
        } catch (Exception e) {
            log.warn("Redis merchant velocity check failed: {}", e.getMessage());
            return 0;
        }
    }
    
    private int checkAmountPatterns(String cardHash, BigDecimal amount) {
        // Check for exact amount repetition (potential testing/fraud)
        String patternKey = "amount_pattern:" + cardHash + ":" + amount.toString();
        
        try {
            String countStr = redisTemplate.opsForValue().get(patternKey);
            int count = countStr != null ? Integer.parseInt(countStr) : 0;
            
            if (count >= 3) {
                log.debug("Suspicious amount pattern: {} repeated {} times", amount, count);
                return 20;
            }
            
            return 0;
            
        } catch (Exception e) {
            log.warn("Redis pattern check failed: {}", e.getMessage());
            return 0;
        }
    }
    
    private int checkTimeBasedRisk() {
        int hour = LocalDateTime.now().getHour();
        
        // Higher risk for late night transactions (11PM - 5AM)
        if (hour >= 23 || hour <= 5) {
            return 10;
        }
        
        return 0;
    }
    
    private void cacheTransaction(String cardHash, String merchantId, BigDecimal amount) {
        try {
            // Cache card velocity (1 hour TTL)
            String cardVelocityKey = "card_velocity:" + cardHash;
            redisTemplate.opsForValue().increment(cardVelocityKey);
            redisTemplate.expire(cardVelocityKey, Duration.ofHours(1));
            
            // Cache card amount velocity (1 hour TTL)
            String cardAmountKey = "card_amount:" + cardHash;
            String currentTotal = redisTemplate.opsForValue().get(cardAmountKey);
            BigDecimal newTotal = (currentTotal != null ? new BigDecimal(currentTotal) : BigDecimal.ZERO).add(amount);
            redisTemplate.opsForValue().set(cardAmountKey, newTotal.toString(), Duration.ofHours(1));
            
            // Cache merchant velocity (10 minute TTL)
            String merchantVelocityKey = "merchant_velocity:" + merchantId;
            redisTemplate.opsForValue().increment(merchantVelocityKey);
            redisTemplate.expire(merchantVelocityKey, Duration.ofMinutes(10));
            
            // Cache amount pattern (24 hour TTL)
            String patternKey = "amount_pattern:" + cardHash + ":" + amount.toString();
            redisTemplate.opsForValue().increment(patternKey);
            redisTemplate.expire(patternKey, Duration.ofHours(24));
            
        } catch (Exception e) {
            log.warn("Failed to cache transaction data: {}", e.getMessage());
            // Don't fail the transaction if caching fails
        }
    }
    
    private String hashCardNumber(String cardNumber) {
        return DigestUtils.sha256Hex(cardNumber + "PAYMENT_SALT_2025");
    }
    
    private String buildReason(int score, List<String> triggeredRules) {
        if (score <= 20) return "Low risk transaction - " + String.join(", ", triggeredRules);
        if (score <= 50) return "Medium risk - approved with monitoring - " + String.join(", ", triggeredRules);
        return "High risk - transaction declined - " + String.join(", ", triggeredRules);
    }
}
