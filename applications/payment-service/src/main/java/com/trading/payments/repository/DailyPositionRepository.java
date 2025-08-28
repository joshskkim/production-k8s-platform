package com.trading.payments.repository;

import com.trading.payments.entity.DailyPosition;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface DailyPositionRepository extends JpaRepository<DailyPosition, Integer> {
    
    Optional<DailyPosition> findByMerchantIdAndPositionDate(String merchantId, LocalDate positionDate);
    
    List<DailyPosition> findByPositionDate(LocalDate positionDate);
    
    List<DailyPosition> findByMerchantIdAndPositionDateBetween(String merchantId, LocalDate startDate, LocalDate endDate);
    
    @Query("SELECT SUM(dp.totalVolume) FROM DailyPosition dp WHERE dp.positionDate = :date")
    BigDecimal getTotalVolumeByDate(@Param("date") LocalDate date);
    
    @Query("SELECT dp FROM DailyPosition dp WHERE dp.positionDate = :date ORDER BY dp.totalVolume DESC")
    List<DailyPosition> findTopMerchantsByVolume(@Param("date") LocalDate date);
}