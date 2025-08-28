-- First, ensure merchants exist (insert if not already there)
INSERT INTO merchants (merchant_id, name, category, risk_level) VALUES
('MERCHANT_001', 'Amazon Store', 'E-COMMERCE', 1),
('MERCHANT_002', 'Gas Station Quick', 'FUEL', 2),
('MERCHANT_003', 'Crypto Exchange Pro', 'FINANCIAL', 3),
('MERCHANT_004', 'Coffee Shop Downtown', 'RESTAURANT', 1),
('MERCHANT_005', 'Electronics Warehouse', 'RETAIL', 2)
ON CONFLICT (merchant_id) DO NOTHING;

-- Now insert risk profiles for existing merchants
INSERT INTO merchant_risk_profiles (merchant_id, daily_limit, monthly_limit, transaction_count_limit, max_single_transaction, risk_tolerance) VALUES
('MERCHANT_001', 50000.00, 1000000.00, 500, 10000.00, 'LOW'),      -- Amazon - high volume, low risk
('MERCHANT_002', 25000.00, 500000.00, 300, 2000.00, 'MEDIUM'),     -- Gas Station - medium volume
('MERCHANT_003', 15000.00, 200000.00, 100, 5000.00, 'HIGH'),       -- Crypto Exchange - high risk, lower limits
('MERCHANT_004', 10000.00, 150000.00, 200, 1000.00, 'LOW'),        -- Coffee Shop - low volume, low risk
('MERCHANT_005', 35000.00, 750000.00, 400, 7500.00, 'MEDIUM')      -- Electronics - medium-high volume
ON CONFLICT (merchant_id) DO NOTHING;

-- Initialize today's positions for all merchants
INSERT INTO daily_positions (merchant_id, position_date, total_volume, transaction_count, approved_volume, approved_count) VALUES
('MERCHANT_001', CURRENT_DATE, 0.00, 0, 0.00, 0),
('MERCHANT_002', CURRENT_DATE, 0.00, 0, 0.00, 0),
('MERCHANT_003', CURRENT_DATE, 0.00, 0, 0.00, 0),
('MERCHANT_004', CURRENT_DATE, 0.00, 0, 0.00, 0),
('MERCHANT_005', CURRENT_DATE, 0.00, 0, 0.00, 0)
ON CONFLICT (merchant_id, position_date) DO NOTHING;