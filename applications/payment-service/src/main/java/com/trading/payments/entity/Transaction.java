@Entity
@Table(name = "transactions")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Transaction {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "transaction_id", unique = true, nullable = false)
    private String transactionId;
    
    @Column(name = "merchant_id", nullable = false)
    private String merchantId;
    
    @Column(name = "card_number_hash", nullable = false)
    private String cardNumberHash;
    
    @Column(name = "amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;
    
    @Column(name = "currency")
    private String currency = "USD";
    
    @Column(name = "status")
    private String status = "pending";
    
    @Column(name = "fraud_score")
    private Integer fraudScore = 0;
    
    @Column(name = "payment_method")
    private String paymentMethod = "card";
    
    @Column(name = "customer_ip")
    private String customerIp;
    
    @Column(name = "user_agent", columnDefinition = "TEXT")
    private String userAgent;
    
    @Column(name = "created_at")
    @CreationTimestamp
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

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
