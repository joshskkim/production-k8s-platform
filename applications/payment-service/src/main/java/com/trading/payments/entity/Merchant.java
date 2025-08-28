@Entity
@Table(name = "merchants")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Merchant {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "merchant_id", unique = true, nullable = false)
    private String merchantId;
    
    @Column(name = "name", nullable = false)
    private String name;
    
    @Column(name = "category")
    private String category;
    
    @Column(name = "risk_level")
    private Integer riskLevel = 1;
    
    @Column(name = "created_at")
    @CreationTimestamp
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    @UpdateTimestamp
    private LocalDateTime updatedAt;
}

@Repository
public interface MerchantRepository extends JpaRepository<Merchant, Long> {
    Optional<Merchant> findByMerchantId(String merchantId);
}
