package com.trading.payments.repository;

import com.trading.payments.entity.MerchantRiskProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.List;

@Repository
public interface MerchantRiskProfileRepository extends JpaRepository<MerchantRiskProfile, Integer> {
    Optional<MerchantRiskProfile> findByMerchantId(String merchantId);
    List<MerchantRiskProfile> findByIsActiveTrue();
}
