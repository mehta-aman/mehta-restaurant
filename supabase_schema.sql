-- ====================================================================
-- MEHTA RESTAURANT MANAGEMENT SYSTEM - SUPABASE POSTGRESQL SCHEMA
-- Paste this entire script into your Supabase Dashboard -> SQL Editor -> Run
-- ====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. RESTAURANT SETTINGS TABLE
CREATE TABLE IF NOT EXISTS restaurant_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurant_name TEXT NOT NULL DEFAULT 'Mehta Restaurant & Sweets',
    address TEXT NOT NULL DEFAULT 'Main Road, Station Road Market',
    phone TEXT NOT NULL DEFAULT '+91 98290 12345',
    gstin TEXT NOT NULL DEFAULT '08AAAAA0000A1Z5',
    gst_enabled BOOLEAN NOT NULL DEFAULT true,
    tax_rate NUMERIC(5, 2) NOT NULL DEFAULT 5.00,
    invoice_prefix TEXT NOT NULL DEFAULT 'MR-',
    next_invoice_number INT NOT NULL DEFAULT 1001,
    upi_id TEXT NOT NULL DEFAULT 'mehtarestaurant@okhdfcbank',
    upi_payee_name TEXT NOT NULL DEFAULT 'Mehta Restaurant',
    inventory_tracking_enabled BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Schema Migration: Add inventory_tracking_enabled column if table already existed
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS inventory_tracking_enabled BOOLEAN DEFAULT false;

-- Seed Initial Settings if empty
INSERT INTO restaurant_settings (restaurant_name, address, phone, gstin, gst_enabled, tax_rate, invoice_prefix, next_invoice_number, upi_id, upi_payee_name)
SELECT 'Mehta Restaurant & Sweets', 'Main Road, Station Road Market', '+91 98290 12345', '08AAAAA0000A1Z5', true, 5.00, 'MR-', 1001, 'mehtarestaurant@okhdfcbank', 'Mehta Restaurant'
WHERE NOT EXISTS (SELECT 1 FROM restaurant_settings);

-- 3. TABLES TABLE (Dining Hall Tables T01 - T10)
CREATE TABLE IF NOT EXISTS tables (
    id TEXT PRIMARY KEY,
    table_number TEXT NOT NULL UNIQUE,
    capacity INT NOT NULL DEFAULT 6,
    status TEXT NOT NULL DEFAULT 'available', -- 'available', 'occupied', 'billed', 'cleaning'
    guest_count INT NOT NULL DEFAULT 0,
    active_order_id TEXT,
    merged_into TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Tables T01 - T10
INSERT INTO tables (id, table_number, capacity, status, guest_count)
VALUES
    ('tbl-0', 'T01', 6, 'available', 0),
    ('tbl-1', 'T02', 6, 'available', 0),
    ('tbl-2', 'T03', 6, 'available', 0),
    ('tbl-3', 'T04', 6, 'available', 0),
    ('tbl-4', 'T05', 6, 'available', 0),
    ('tbl-5', 'T06', 6, 'available', 0),
    ('tbl-6', 'T07', 6, 'available', 0),
    ('tbl-7', 'T08', 6, 'available', 0),
    ('tbl-8', 'T09', 6, 'available', 0),
    ('tbl-9', 'T10', 6, 'available', 0)
ON CONFLICT (table_number) DO NOTHING;

-- 4. MENU ITEMS TABLE
CREATE TABLE IF NOT EXISTS menu_items (
    id TEXT PRIMARY KEY,
    sku TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    is_veg BOOLEAN NOT NULL DEFAULT true,
    is_available BOOLEAN NOT NULL DEFAULT true,
    is_packaged BOOLEAN NOT NULL DEFAULT false,
    stock_quantity INT NOT NULL DEFAULT 0,
    low_stock_threshold INT NOT NULL DEFAULT 5,
    description TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Authentic Indian Menu Items
INSERT INTO menu_items (id, sku, name, category, price, is_veg, is_packaged, stock_quantity, low_stock_threshold)
VALUES
    -- Starters
    ('1', 'STR-01', 'Paneer Tikka (6 pcs)', 'Starters', 220.00, true, false, 0, 5),
    ('2', 'STR-02', 'Veg Hara Bhara Kebab', 'Starters', 180.00, true, false, 0, 5),
    ('3', 'STR-03', 'Crispy Corn Salt & Pepper', 'Starters', 190.00, true, false, 0, 5),
    ('4', 'STR-04', 'Dahi ke Kebab', 'Starters', 210.00, true, false, 0, 5),
    ('5', 'STR-05', 'Spring Rolls', 'Starters', 160.00, true, false, 0, 5),
    ('6', 'STR-06', 'Chilli Paneer Dry', 'Starters', 230.00, true, false, 0, 5),
    -- Main Course
    ('7', 'MNC-01', 'Paneer Butter Masala', 'Main Course', 260.00, true, false, 0, 5),
    ('8', 'MNC-02', 'Kadhai Paneer', 'Main Course', 250.00, true, false, 0, 5),
    ('9', 'MNC-03', 'Shahi Paneer', 'Main Course', 270.00, true, false, 0, 5),
    ('10', 'MNC-04', 'Dal Makhani', 'Main Course', 210.00, true, false, 0, 5),
    ('11', 'MNC-05', 'Dal Tadka (Yellow)', 'Main Course', 180.00, true, false, 0, 5),
    ('12', 'MNC-06', 'Malai Kofta', 'Main Course', 280.00, true, false, 0, 5),
    ('13', 'MNC-07', 'Mix Veg Handi', 'Main Course', 220.00, true, false, 0, 5),
    ('14', 'MNC-08', 'Kaju Curry', 'Main Course', 320.00, true, false, 0, 5),
    ('15', 'MNC-09', 'Dum Aloo Kashmiri', 'Main Course', 210.00, true, false, 0, 5),
    ('16', 'MNC-10', 'Mushroom Masala', 'Main Course', 240.00, true, false, 0, 5),
    -- Breads
    ('17', 'BRD-01', 'Tandoori Roti (Plain)', 'Breads', 20.00, true, false, 0, 5),
    ('18', 'BRD-02', 'Butter Roti', 'Breads', 25.00, true, false, 0, 5),
    ('19', 'BRD-03', 'Butter Naan', 'Breads', 45.00, true, false, 0, 5),
    ('20', 'BRD-04', 'Garlic Naan', 'Breads', 60.00, true, false, 0, 5),
    ('21', 'BRD-05', 'Laccha Paratha', 'Breads', 45.00, true, false, 0, 5),
    ('22', 'BRD-06', 'Missi Roti', 'Breads', 35.00, true, false, 0, 5),
    -- Rice & Biryani
    ('23', 'RIC-01', 'Jeera Rice', 'Rice & Biryani', 140.00, true, false, 0, 5),
    ('24', 'RIC-02', 'Veg Dum Biryani', 'Rice & Biryani', 220.00, true, false, 0, 5),
    ('25', 'RIC-03', 'Steamed Basmati Rice', 'Rice & Biryani', 110.00, true, false, 0, 5),
    -- Desserts & Beverages
    ('26', 'BEV-01', 'Masala Chaas (Spiced Buttermilk)', 'Beverages', 40.00, true, false, 0, 5),
    ('27', 'BEV-02', 'Sweet Lassi (Kulhad)', 'Beverages', 70.00, true, false, 0, 5),
    ('28', 'DST-01', 'Gulab Jamun (2 pcs)', 'Desserts', 60.00, true, false, 0, 5),
    ('29', 'DST-02', 'Rasgulla (2 pcs)', 'Desserts', 60.00, true, false, 0, 5),
    ('30', 'DST-03', 'Matka Kulfi', 'Desserts', 80.00, true, false, 0, 5),
    -- Packaged Goods (Bikaji / Namkeen / Cold Drinks)
    ('31', 'PKG-001', 'Bikaji Bhujia 200g', 'Packaged Goods', 55.00, true, true, 28, 5),
    ('32', 'PKG-002', 'Bikaji Navratan Mixture 200g', 'Packaged Goods', 55.00, true, true, 19, 5),
    ('33', 'PKG-003', 'Bikaji Rasgulla Tin 1kg', 'Packaged Goods', 240.00, true, true, 8, 3),
    ('34', 'PKG-004', 'Bikaji Soan Papdi 500g', 'Packaged Goods', 140.00, true, true, 12, 4),
    ('35', 'PKG-005', 'Bikaji Moong Dal 200g', 'Packaged Goods', 55.00, true, true, 22, 5),
    ('36', 'PKG-006', 'Bisleri Mineral Water 1L', 'Packaged Goods', 20.00, true, true, 45, 10),
    ('37', 'PKG-007', 'Coca Cola Can 300ml', 'Packaged Goods', 40.00, true, true, 24, 6),
    ('38', 'PKG-008', 'Thums Up Bottle 500ml', 'Packaged Goods', 45.00, true, true, 18, 6)
ON CONFLICT (sku) DO NOTHING;

-- 5. CUSTOMERS TABLE
CREATE TABLE IF NOT EXISTS customers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Initial Regular Customers
INSERT INTO customers (id, name, phone, notes)
VALUES
    ('c1', 'Raj Sharma', '9829012345', 'Monthly regular customer'),
    ('c2', 'Amit Traders (Verma Ji)', '9414056789', 'Staff dining account'),
    ('c3', 'Gupta Family', '9783011223', 'Nearby resident')
ON CONFLICT (id) DO NOTHING;

-- 6. LEDGER ENTRIES TABLE (Khata Credit & Settlements)
CREATE TABLE IF NOT EXISTS ledger_entries (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'debit' (owes money / bill added) or 'credit' (paid back / settlement)
    amount NUMERIC(10, 2) NOT NULL,
    reference_type TEXT NOT NULL, -- 'INVOICE', 'PAYMENT', 'OPENING_BALANCE'
    reference_number TEXT NOT NULL,
    description TEXT NOT NULL,
    date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed Initial Transactions
INSERT INTO ledger_entries (id, customer_id, type, amount, reference_type, reference_number, description, date)
VALUES
    ('l1', 'c1', 'debit', 3850.00, 'INVOICE', 'MR-000001', 'Dinner Party - T06', NOW() - INTERVAL '3 days'),
    ('l2', 'c1', 'credit', 1000.00, 'PAYMENT', 'UPI-TXN-9021', 'UPI Settlement (GPay)', NOW() - INTERVAL '1 day'),
    ('l3', 'c2', 'debit', 12400.00, 'INVOICE', 'MR-000003', 'Office catering account', NOW() - INTERVAL '5 days')
ON CONFLICT (id) DO NOTHING;

-- 7. INVOICES & ORDERS TABLES
CREATE TABLE IF NOT EXISTS invoices (
    id TEXT PRIMARY KEY,
    invoice_number TEXT NOT NULL UNIQUE,
    table_number TEXT NOT NULL,
    subtotal NUMERIC(10, 2) NOT NULL,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    grand_total NUMERIC(10, 2) NOT NULL,
    cash_paid NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    upi_paid NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    credit_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    customer_name TEXT,
    customer_phone TEXT,
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    splits JSONB,
    split_summary TEXT,
    is_voided BOOLEAN NOT NULL DEFAULT false,
    void_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. KITCHEN TICKETS TABLE
CREATE TABLE IF NOT EXISTS kitchen_tickets (
    id TEXT PRIMARY KEY,
    kot_number TEXT NOT NULL,
    order_id TEXT NOT NULL,
    table_number TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'newTicket', -- 'newTicket', 'preparing', 'ready', 'served'
    is_rush BOOLEAN NOT NULL DEFAULT false,
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. ROW LEVEL SECURITY (RLS) POLICIES
-- Enable RLS
ALTER TABLE restaurant_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE kitchen_tickets ENABLE ROW LEVEL SECURITY;

-- Allow Public / Anon Read & Write for Restaurant POS & Guest Menu
DO $$
BEGIN
    DROP POLICY IF EXISTS "Public Read Tables" ON tables;
    CREATE POLICY "Public Read Tables" ON tables FOR SELECT USING (true);

    DROP POLICY IF EXISTS "Public Update Tables" ON tables;
    CREATE POLICY "Public Update Tables" ON tables FOR ALL USING (true);

    DROP POLICY IF EXISTS "Public Read Menu Items" ON menu_items;
    CREATE POLICY "Public Read Menu Items" ON menu_items FOR SELECT USING (true);

    DROP POLICY IF EXISTS "Public Write Menu Items" ON menu_items;
    CREATE POLICY "Public Write Menu Items" ON menu_items FOR ALL USING (true);

    DROP POLICY IF EXISTS "Public Access Settings" ON restaurant_settings;
    CREATE POLICY "Public Access Settings" ON restaurant_settings FOR ALL USING (true);

    DROP POLICY IF EXISTS "Public Access Customers" ON customers;
    CREATE POLICY "Public Access Customers" ON customers FOR ALL USING (true);

    DROP POLICY IF EXISTS "Public Access Ledger" ON ledger_entries;
    CREATE POLICY "Public Access Ledger" ON ledger_entries FOR ALL USING (true);

    DROP POLICY IF EXISTS "Public Access Invoices" ON invoices;
    CREATE POLICY "Public Access Invoices" ON invoices FOR ALL USING (true);

    DROP POLICY IF EXISTS "Public Access Kitchen Tickets" ON kitchen_tickets;
    CREATE POLICY "Public Access Kitchen Tickets" ON kitchen_tickets FOR ALL USING (true);
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- Enable Realtime on key live sync tables
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE tables, menu_items, kitchen_tickets, ledger_entries;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- ==============================================================================
-- MIGRATION 008: AI ASSISTANT & BATCH MENU IMPORT
-- ==============================================================================
CREATE TABLE IF NOT EXISTS ai_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id TEXT,
    staff_name TEXT,
    staff_role TEXT NOT NULL,
    tool_name TEXT NOT NULL,
    arguments JSONB DEFAULT '{}'::jsonb,
    success BOOLEAN NOT NULL DEFAULT true,
    error_message TEXT,
    user_prompt TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_audit_created ON ai_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_audit_tool ON ai_audit_logs(tool_name);

CREATE TABLE IF NOT EXISTS ai_action_confirmations (
    token TEXT PRIMARY KEY,
    operation_name TEXT NOT NULL,
    parameters JSONB NOT NULL DEFAULT '{}'::jsonb,
    staff_id TEXT NOT NULL,
    staff_role TEXT NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    is_consumed BOOLEAN NOT NULL DEFAULT false,
    consumed_at TIMESTAMPTZ,
    state_snapshot JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_ai_confirm_expires ON ai_action_confirmations(expires_at);

CREATE OR REPLACE FUNCTION import_menu_items_batch(
    p_items JSONB,
    p_mode TEXT DEFAULT 'upsert',
    p_staff_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, auth, pg_temp
AS $$
DECLARE
    v_item JSONB;
    v_name TEXT;
    v_category TEXT;
    v_price NUMERIC;
    v_is_veg BOOLEAN;
    v_is_packaged BOOLEAN;
    v_stock INT;
    v_sku TEXT;
    v_desc TEXT;
    v_existing_id TEXT;
    v_cat_id UUID;
    v_created INT := 0;
    v_updated INT := 0;
    v_skipped INT := 0;
    v_errors JSONB := '[]'::jsonb;
    v_row_idx INT := 0;
BEGIN
    IF jsonb_typeof(p_items) <> 'array' THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid payload: p_items must be a JSON array of menu items.'
        );
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_row_idx := v_row_idx + 1;
        v_name := TRIM(COALESCE(v_item->>'name', ''));
        v_category := TRIM(COALESCE(v_item->>'category', 'Main Course'));
        v_price := (v_item->>'price')::NUMERIC;
        v_is_veg := COALESCE((v_item->>'is_veg')::BOOLEAN, true);
        v_is_packaged := COALESCE((v_item->>'is_packaged')::BOOLEAN, false);
        v_stock := COALESCE((v_item->>'stock_quantity')::INT, 0);
        v_sku := TRIM(COALESCE(v_item->>'sku', ''));
        v_desc := v_item->>'description';

        IF v_name = '' THEN
            v_errors := v_errors || jsonb_build_object('row', v_row_idx, 'error', 'Dish name is required');
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;

        IF v_price IS NULL OR v_price < 0 THEN
            v_errors := v_errors || jsonb_build_object('row', v_row_idx, 'item', v_name, 'error', 'Valid non-negative price is required');
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;

        SELECT id INTO v_cat_id FROM menu_categories WHERE LOWER(name) = LOWER(v_category) LIMIT 1;
        IF v_cat_id IS NULL THEN
            INSERT INTO menu_categories (name, display_order)
            VALUES (v_category, 10)
            ON CONFLICT (name) DO NOTHING
            RETURNING id INTO v_cat_id;

            IF v_cat_id IS NULL THEN
                SELECT id INTO v_cat_id FROM menu_categories WHERE LOWER(name) = LOWER(v_category) LIMIT 1;
            END IF;
        END IF;

        SELECT id INTO v_existing_id FROM menu_items WHERE LOWER(TRIM(name)) = LOWER(v_name) LIMIT 1;

        IF v_existing_id IS NOT NULL THEN
            IF p_mode = 'create_only' THEN
                v_skipped := v_skipped + 1;
                v_errors := v_errors || jsonb_build_object('row', v_row_idx, 'item', v_name, 'status', 'skipped_duplicate');
                CONTINUE;
            ELSE
                UPDATE menu_items
                SET price = v_price,
                    category = v_category,
                    category_id = v_cat_id,
                    is_veg = v_is_veg,
                    is_available = true,
                    is_packaged = v_is_packaged,
                    stock_quantity = CASE WHEN v_is_packaged THEN v_stock ELSE stock_quantity END,
                    description = COALESCE(v_desc, description),
                    updated_at = NOW()
                WHERE id = v_existing_id;

                v_updated := v_updated + 1;
            END IF;
        ELSE
            INSERT INTO menu_items (
                id, name, sku, category, category_id, price,
                is_veg, is_available, is_packaged, stock_quantity,
                description, updated_at
            ) VALUES (
                'mi_' || gen_random_uuid()::text,
                v_name,
                COALESCE(NULLIF(v_sku, ''), 'SKU-' || lpad(v_row_idx::text, 4, '0')),
                v_category,
                v_cat_id,
                v_price,
                v_is_veg,
                true,
                v_is_packaged,
                v_stock,
                v_desc,
                NOW()
            );

            v_created := v_created + 1;
        END IF;
    END LOOP;

    INSERT INTO ai_audit_logs (staff_id, staff_role, tool_name, arguments, success, user_prompt)
    VALUES (
        p_staff_id::text,
        'authorized',
        'import_menu_items_batch',
        jsonb_build_object('total', jsonb_array_length(p_items), 'created', v_created, 'updated', v_updated, 'skipped', v_skipped),
        true,
        'Bulk menu import batch execution'
    );

    RETURN jsonb_build_object(
        'success', true,
        'total_rows', v_row_idx,
        'created_count', v_created,
        'updated_count', v_updated,
        'skipped_count', v_skipped,
        'errors', v_errors
    );
END;
$$;

GRANT EXECUTE ON FUNCTION import_menu_items_batch(JSONB, TEXT, UUID) TO anon, authenticated, service_role;

DO $$
BEGIN
    ALTER TABLE ai_audit_logs ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access AI Audit Logs" ON ai_audit_logs;
    CREATE POLICY "Public Access AI Audit Logs" ON ai_audit_logs FOR ALL USING (true) WITH CHECK (true);

    ALTER TABLE ai_action_confirmations ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access AI Confirmations" ON ai_action_confirmations;
    CREATE POLICY "Public Access AI Confirmations" ON ai_action_confirmations FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

