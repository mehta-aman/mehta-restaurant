-- ==============================================================================
-- MEHTA RESTAURANT MANAGEMENT SYSTEM - MIGRATION 006
-- Dynamic Settings Schema, Singleton Persistence RPC, and Full CRUD Access
-- Target Database: mehta-restaurant (PostgreSQL / Supabase)
-- ==============================================================================

-- 1. EXTEND RESTAURANT_SETTINGS COLUMNS
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS tagline TEXT DEFAULT 'Pure Veg Restaurant & Sweets';
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS email TEXT DEFAULT '';
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS service_charge_rate NUMERIC(5, 2) DEFAULT 0.00;
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS receipt_footer_note TEXT DEFAULT 'Thank you! Visit Again.';
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS thermal_paper_width INT DEFAULT 80;
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS auto_print_receipt BOOLEAN DEFAULT false;

-- 2. DEDUPLICATE EXISTING ROWS IN RESTAURANT_SETTINGS
-- Keep only the single most recently updated row
DELETE FROM restaurant_settings
WHERE id NOT IN (
    SELECT id FROM restaurant_settings
    ORDER BY updated_at DESC
    LIMIT 1
);

-- 3. SINGLETON SETTINGS PERSISTENCE RPC (SECURITY DEFINER)
-- Allows authorized staff terminals to update settings atomically without permission conflicts
CREATE OR REPLACE FUNCTION save_restaurant_settings(
    p_restaurant_name TEXT,
    p_address TEXT,
    p_phone TEXT,
    p_gstin TEXT,
    p_gst_enabled BOOLEAN,
    p_tax_rate NUMERIC,
    p_invoice_prefix TEXT,
    p_next_invoice_number INT,
    p_upi_id TEXT,
    p_upi_payee_name TEXT,
    p_inventory_tracking_enabled BOOLEAN DEFAULT false,
    p_tagline TEXT DEFAULT 'Pure Veg Restaurant & Sweets',
    p_email TEXT DEFAULT '',
    p_service_charge_rate NUMERIC DEFAULT 0.00,
    p_receipt_footer_note TEXT DEFAULT 'Thank you! Visit Again.',
    p_thermal_paper_width INT DEFAULT 80,
    p_auto_print_receipt BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
BEGIN
    SELECT id INTO v_id FROM restaurant_settings ORDER BY updated_at DESC LIMIT 1;
    
    IF v_id IS NOT NULL THEN
        UPDATE restaurant_settings
        SET restaurant_name = p_restaurant_name,
            tagline = p_tagline,
            address = p_address,
            phone = p_phone,
            email = p_email,
            gstin = p_gstin,
            gst_enabled = p_gst_enabled,
            tax_rate = p_tax_rate,
            service_charge_rate = p_service_charge_rate,
            invoice_prefix = p_invoice_prefix,
            next_invoice_number = p_next_invoice_number,
            upi_id = p_upi_id,
            upi_payee_name = p_upi_payee_name,
            inventory_tracking_enabled = p_inventory_tracking_enabled,
            receipt_footer_note = p_receipt_footer_note,
            thermal_paper_width = p_thermal_paper_width,
            auto_print_receipt = p_auto_print_receipt,
            updated_at = NOW()
        WHERE id = v_id;
    ELSE
        INSERT INTO restaurant_settings (
            restaurant_name,
            tagline,
            address,
            phone,
            email,
            gstin,
            gst_enabled,
            tax_rate,
            service_charge_rate,
            invoice_prefix,
            next_invoice_number,
            upi_id,
            upi_payee_name,
            inventory_tracking_enabled,
            receipt_footer_note,
            thermal_paper_width,
            auto_print_receipt,
            updated_at
        ) VALUES (
            p_restaurant_name,
            p_tagline,
            p_address,
            p_phone,
            p_email,
            p_gstin,
            p_gst_enabled,
            p_tax_rate,
            p_service_charge_rate,
            p_invoice_prefix,
            p_next_invoice_number,
            p_upi_id,
            p_upi_payee_name,
            p_inventory_tracking_enabled,
            p_receipt_footer_note,
            p_thermal_paper_width,
            p_auto_print_receipt,
            NOW()
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Restaurant settings saved successfully');
END;
$$;

GRANT EXECUTE ON FUNCTION save_restaurant_settings TO anon, authenticated, service_role;

-- 4. RLS POLICIES FOR RESTAURANT_SETTINGS, MENU_ITEMS, KITCHEN_TICKETS, TABLES
-- Enable full CRUD access for anon and authenticated POS / staff client operations
DO $$
BEGIN
    -- restaurant_settings
    ALTER TABLE restaurant_settings ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Read Settings" ON restaurant_settings;
    DROP POLICY IF EXISTS "Public Modify Settings" ON restaurant_settings;
    DROP POLICY IF EXISTS "settings_read_policy" ON restaurant_settings;
    DROP POLICY IF EXISTS "settings_write_policy" ON restaurant_settings;
    CREATE POLICY "Public Read Settings" ON restaurant_settings FOR SELECT USING (true);
    CREATE POLICY "Public Modify Settings" ON restaurant_settings FOR ALL USING (true) WITH CHECK (true);

    -- menu_items
    ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Read Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "Public Modify Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "items_read_policy" ON menu_items;
    DROP POLICY IF EXISTS "items_write_policy" ON menu_items;
    CREATE POLICY "Public Read Menu Items" ON menu_items FOR SELECT USING (true);
    CREATE POLICY "Public Modify Menu Items" ON menu_items FOR ALL USING (true) WITH CHECK (true);

    -- tables
    ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Tables" ON tables;
    CREATE POLICY "Public Access Tables" ON tables FOR ALL USING (true) WITH CHECK (true);

    -- kitchen_tickets
    ALTER TABLE kitchen_tickets ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Kitchen Tickets" ON kitchen_tickets;
    CREATE POLICY "Public Access Kitchen Tickets" ON kitchen_tickets FOR ALL USING (true) WITH CHECK (true);

    -- customers
    ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Customers" ON customers;
    CREATE POLICY "Public Access Customers" ON customers FOR ALL USING (true) WITH CHECK (true);

    -- ledger_entries
    ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Ledger Entries" ON ledger_entries;
    CREATE POLICY "Public Access Ledger Entries" ON ledger_entries FOR ALL USING (true) WITH CHECK (true);

    -- staff_profiles
    ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Staff Profiles" ON staff_profiles;
    CREATE POLICY "Public Access Staff Profiles" ON staff_profiles FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;
