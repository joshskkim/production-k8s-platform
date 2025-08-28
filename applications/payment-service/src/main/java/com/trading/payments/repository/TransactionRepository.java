package com.trading.payments.repository;

import com.trading.payments.entity.Transaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long> {
    
    Optional<Transaction> findByTransactionId(String transactionId);
    
    List<Transaction> findByMerchantIdAndCreatedAtAfter(String merchantId, LocalDateTime since);
    
    @Query("SELECT COUNT(t) FROM Transaction t WHERE t.merchantId = :merchantId AND t.createdAt > :since")
    Long countTransactionsByMerchantSince(@Param("merchantId") String merchantId, @Param("since") LocalDateTime since);
    
    @Query("SELECT SUM(t.amount) FROM Transaction t WHERE t.merchantId = :merchantId AND t.status = 'approved' AND t.createdAt > :since")
    BigDecimal sumApprovedAmountByMerchantSince(@Param("merchantId") String merchantId, @Param("since") LocalDateTime since);
    
    @Query("SELECT COUNT(t) FROM Transaction t WHERE t.cardNumberHash = :cardHash AND t.createdAt > :since")
    Long countTransactionsByCardSince(@Param("cardHash") String cardHash, @Param("since") LocalDateTime since);
    
    @Query("SELECT AVG(t.fraudScore) FROM Transaction t WHERE t.merchantId = :merchantId AND t.createdAt > :since")
    Double averageFraudScoreByMerchantSince(@Param("merchantId") String merchantId, @Param("since") LocalDateTime since);
}
