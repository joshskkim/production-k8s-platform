package com.trading.payments.repository;

import com.trading.payments.entity.RiskAlert;
import com.trading.payments.entity.AlertType;
import com.trading.payments.entity.AlertLevel;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface RiskAlertRepository extends JpaRepository<RiskAlert, Integer> {
    
    List<RiskAlert> findByMerchantIdAndIsResolvedFalse(String merchantId);
    
    List<RiskAlert> findByIsResolvedFalseOrderByCreatedAtDesc();
    
    List<RiskAlert> findByAlertLevelAndIsResolvedFalse(AlertLevel alertLevel);
    
    Long countByIsResolvedFalseAndCreatedAtAfter(LocalDateTime since);
    
    @Query("SELECT ra FROM RiskAlert ra WHERE ra.merchantId = :merchantId AND ra.createdAt >= :since ORDER BY ra.createdAt DESC")
    List<RiskAlert> findRecentAlertsByMerchant(@Param("merchantId") String merchantId, @Param("since") LocalDateTime since);
    
    @Query("SELECT COUNT(ra) FROM RiskAlert ra WHERE ra.alertType = :alertType AND ra.createdAt >= :since")
    Long countByAlertTypeSince(@Param("alertType") AlertType alertType, @Param("since") LocalDateTime since);
}
