-- Insert sample merchants
INSERT INTO merchants (merchant_id, name, category, risk_level) VALUES
('MERCHANT_001', 'Amazon Store', 'E-COMMERCE', 1),
('MERCHANT_002', 'Gas Station Quick', 'FUEL', 2),
('MERCHANT_003', 'Crypto Exchange Pro', 'FINANCIAL', 3),
('MERCHANT_004', 'Coffee Shop Downtown', 'RESTAURANT', 1),
('MERCHANT_005', 'Electronics Warehouse', 'RETAIL', 2)
ON CONFLICT (merchant_id) DO NOTHING;

-- Insert sample fraud rules
INSERT INTO fraud_rules (rule_name, rule_type, threshold_value, time_window_minutes, risk_score) VALUES
('High Amount Transaction', 'amount', 1000.00, NULL, 25),
('Velocity Check - Same Card', 'velocity', 5, 60, 20),
('Large Amount Velocity', 'amount_velocity', 2000.00, 1440, 30),
('Suspicious Amount Pattern', 'amount', 9999.99, NULL, 50),
('High Risk Merchant', 'merchant', NULL, NULL, 15)
ON CONFLICT DO NOTHING;