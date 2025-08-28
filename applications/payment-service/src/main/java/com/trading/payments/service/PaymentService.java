package com.trading.payments.service;

import com.trading.payments.entity.Transaction;
import com.trading.payments.repository.TransactionRepository;
import com.trading.payments.dto.*;
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
