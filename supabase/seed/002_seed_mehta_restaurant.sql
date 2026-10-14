-- ==============================================================================
-- MEHTA RESTAURANT SEED DATA
-- Default Tables, Menu Items, Packaged Goods, and Settings
-- ==============================================================================

-- 1. RESTAURANT SETTINGS (GST disabled initially, customizable)
INSERT INTO restaurant_settings (
    restaurant_name,
    address,
    phone,
    gst_enabled,
    gstin,
    default_tax_rate,
    invoice_prefix,
    invoice_next_number,
    receipt_footer_note
) VALUES (
    'Mehta Restaurant',
    'Main Market Road, Ground Floor',
    '+91 98765 43210',
    FALSE,
    NULL,
    5.00,
    'MR-',
    1,
    'Thank you for dining at Mehta Restaurant! Visit again.'
) ON CONFLICT DO NOTHING;

-- 2. TABLES (10 Tables, Capacity 6, Floor: Main Hall)
INSERT INTO restaurant_tables (table_number, floor_section, seating_capacity, status) VALUES
('T01', 'Main Hall', 6, 'available'),
('T02', 'Main Hall', 6, 'available'),
('T03', 'Main Hall', 6, 'available'),
('T04', 'Main Hall', 6, 'available'),
('T05', 'Main Hall', 6, 'available'),
('T06', 'Main Hall', 6, 'available'),
('T07', 'Main Hall', 6, 'available'),
('T08', 'Main Hall', 6, 'available'),
('T09', 'Main Hall', 6, 'available'),
('T10', 'Main Hall', 6, 'available')
ON CONFLICT (table_number) DO NOTHING;

-- 3. MENU CATEGORIES
INSERT INTO menu_categories (name, display_order) VALUES
('Starters', 1),
('Main Course', 2),
('Breads & Roti', 3),
('Rice & Biryani', 4),
('Desserts', 5),
('Packaged Namkeen & Snacks', 6),
('Beverages & Cold Drinks', 7)
ON CONFLICT (name) DO NOTHING;

-- 4. MENU ITEMS & PACKAGED PRODUCTS (~30 Prepared Dishes + Packaged Goods)
DO $$
DECLARE
    cat_starters UUID;
    cat_main UUID;
    cat_breads UUID;
    cat_rice UUID;
    cat_dessert UUID;
    cat_packaged UUID;
    cat_beverages UUID;
BEGIN
    SELECT id INTO cat_starters FROM menu_categories WHERE name = 'Starters';
    SELECT id INTO cat_main FROM menu_categories WHERE name = 'Main Course';
    SELECT id INTO cat_breads FROM menu_categories WHERE name = 'Breads & Roti';
    SELECT id INTO cat_rice FROM menu_categories WHERE name = 'Rice & Biryani';
    SELECT id INTO cat_dessert FROM menu_categories WHERE name = 'Desserts';
    SELECT id INTO cat_packaged FROM menu_categories WHERE name = 'Packaged Namkeen & Snacks';
    SELECT id INTO cat_beverages FROM menu_categories WHERE name = 'Beverages & Cold Drinks';

    -- Starters
    INSERT INTO menu_items (category_id, name, sku, price, is_packaged_product, is_veg) VALUES
    (cat_starters, 'Paneer Tikka', 'STR-01', 220.00, FALSE, TRUE),
    (cat_starters, 'Hara Bhara Kabab', 'STR-02', 180.00, FALSE, TRUE),
    (cat_starters, 'Veg Crispy', 'STR-03', 190.00, FALSE, TRUE),
    (cat_starters, 'Veg Spring Roll', 'STR-04', 160.00, FALSE, TRUE),
    (cat_starters, 'Crispy Corn Salt & Pepper', 'STR-05', 170.00, FALSE, TRUE),
    (cat_starters, 'Chilli Paneer Dry', 'STR-06', 210.00, FALSE, TRUE)
    ON CONFLICT (sku) DO NOTHING;

    -- Main Course
    INSERT INTO menu_items (category_id, name, sku, price, is_packaged_product, is_veg) VALUES
    (cat_main, 'Paneer Butter Masala', 'MNC-01', 240.00, FALSE, TRUE),
    (cat_main, 'Kadhai Paneer', 'MNC-02', 250.00, FALSE, TRUE),
    (cat_main, 'Shahi Paneer', 'MNC-03', 260.00, FALSE, TRUE),
    (cat_main, 'Dal Makhani', 'MNC-04', 210.00, FALSE, TRUE),
    (cat_main, 'Dal Tadka (Yellow)', 'MNC-05', 170.00, FALSE, TRUE),
    (cat_main, 'Mix Vegetable', 'MNC-06', 190.00, FALSE, TRUE),
    (cat_main, 'Chana Masala', 'MNC-07', 180.00, FALSE, TRUE),
    (cat_main, 'Malai Kofta', 'MNC-08', 260.00, FALSE, TRUE),
    (cat_main, 'Mushroom Do Pyaza', 'MNC-09', 240.00, FALSE, TRUE),
    (cat_main, 'Aloo Gobi Adraki', 'MNC-10', 160.00, FALSE, TRUE)
    ON CONFLICT (sku) DO NOTHING;

    -- Breads & Roti
    INSERT INTO menu_items (category_id, name, sku, price, is_packaged_product, is_veg) VALUES
    (cat_breads, 'Tandoori Roti Plain', 'BRD-01', 15.00, FALSE, TRUE),
    (cat_breads, 'Tandoori Butter Roti', 'BRD-02', 20.00, FALSE, TRUE),
    (cat_breads, 'Butter Naan', 'BRD-03', 45.00, FALSE, TRUE),
    (cat_breads, 'Garlic Naan', 'BRD-04', 60.00, FALSE, TRUE),
    (cat_breads, 'Lachha Paratha', 'BRD-05', 40.00, FALSE, TRUE),
    (cat_breads, 'Missi Roti', 'BRD-06', 35.00, FALSE, TRUE)
    ON CONFLICT (sku) DO NOTHING;

    -- Rice & Biryani
    INSERT INTO menu_items (category_id, name, sku, price, is_packaged_product, is_veg) VALUES
    (cat_rice, 'Steamed Plain Rice', 'RIC-01', 110.00, FALSE, TRUE),
    (cat_rice, 'Jeera Rice', 'RIC-02', 130.00, FALSE, TRUE),
    (cat_rice, 'Veg Pulao', 'RIC-03', 160.00, FALSE, TRUE),
    (cat_rice, 'Special Veg Biryani with Raita', 'RIC-04', 220.00, FALSE, TRUE)
    ON CONFLICT (sku) DO NOTHING;

    -- Desserts
    INSERT INTO menu_items (category_id, name, sku, price, is_packaged_product, is_veg) VALUES
    (cat_dessert, 'Gulab Jamun (2 pcs)', 'DES-01', 60.00, FALSE, TRUE),
    (cat_dessert, 'Rasgulla (2 pcs)', 'DES-02', 60.00, FALSE, TRUE),
    (cat_dessert, 'Vanilla Ice Cream', 'DES-03', 50.00, FALSE, TRUE),
    (cat_dessert, 'Kesar Pista Kulfi', 'DES-04', 70.00, FALSE, TRUE)
    ON CONFLICT (sku) DO NOTHING;

    -- Packaged Snacks & Namkeen (Bikaji & Biscuits)
    INSERT INTO menu_items (category_id, name, sku, price, is_packaged_product, is_veg) VALUES
    (cat_packaged, 'Bikaji Bhujia (200g)', 'PKG-01', 65.00, TRUE, TRUE),
    (cat_packaged, 'Bikaji All-in-One Mixture (200g)', 'PKG-02', 65.00, TRUE, TRUE),
    (cat_packaged, 'Bikaji Navratna Mixture (200g)', 'PKG-03', 65.00, TRUE, TRUE),
    (cat_packaged, 'Bikaji Rasgulla Tin (1kg)', 'PKG-04', 240.00, TRUE, TRUE),
    (cat_packaged, 'Parle-G Biscuit Pack', 'PKG-05', 10.00, TRUE, TRUE),
    (cat_packaged, 'Britannia Good Day Butter', 'PKG-06', 25.00, TRUE, TRUE)
    ON CONFLICT (sku) DO NOTHING;

    -- Beverages & Cold Drinks
    INSERT INTO menu_items (category_id, name, sku, price, is_packaged_product, is_veg) VALUES
    (cat_beverages, 'Packaged Mineral Water (1 Litre)', 'BEV-01', 20.00, TRUE, TRUE),
    (cat_beverages, 'Thums Up (250ml Can)', 'BEV-02', 35.00, TRUE, TRUE),
    (cat_beverages, 'Coca Cola (250ml Can)', 'BEV-03', 35.00, TRUE, TRUE),
    (cat_beverages, 'Sprite (250ml Can)', 'BEV-04', 35.00, TRUE, TRUE),
    (cat_beverages, 'Cold Drink Bottle (750ml)', 'BEV-05', 50.00, TRUE, TRUE),
    (cat_beverages, 'Fresh Sweet Lassi', 'BEV-06', 60.00, FALSE, TRUE),
    (cat_beverages, 'Masala Buttermilk / Chaas', 'BEV-07', 30.00, FALSE, TRUE)
    ON CONFLICT (sku) DO NOTHING;
END $$;

-- 5. SAMPLE CUSTOMER & TRANSACTIONAL LEDGER (Demonstrating Credit System)
DO $$
DECLARE
    cust_id UUID;
BEGIN
    INSERT INTO customers (name, phone, notes)
    VALUES ('Raj Sharma', '+919829012345', 'Frequent visitor, monthly settlement')
    ON CONFLICT (phone) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO cust_id;

    -- Initial Ledger Entry
    INSERT INTO customer_ledger (customer_id, entry_type, amount, reference_type, description)
    VALUES 
    (cust_id, 'debit', 3850.00, 'INVOICE', 'Dining Session - T06'),
    (cust_id, 'credit', 2000.00, 'PAYMENT', 'UPI Payment (GPay)')
    ON CONFLICT DO NOTHING;
END $$;
