-- ==============================================================================
-- MEHTA RESTAURANT MANAGEMENT SYSTEM - MIGRATION 007
-- Authoritative Backend Sync, Full CRUD Policies, and Atomic Deletion/Update RPCs
-- Target Database: mehta-restaurant (PostgreSQL / Supabase)
-- ==============================================================================

-- 1. EXTEND INVOICES TABLE SCHEMA
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS is_voided BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS void_reason TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS split_summary TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS splits JSONB;

-- 2. EXTEND RESTAURANT SETTINGS SCHEMA
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS tagline TEXT DEFAULT 'Pure Veg Restaurant & Sweets';
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS email TEXT DEFAULT '';
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS service_charge_rate NUMERIC(5, 2) DEFAULT 0.00;
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS receipt_footer_note TEXT DEFAULT 'Thank you! Visit Again.';
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS thermal_paper_width INT DEFAULT 80;
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS auto_print_receipt BOOLEAN DEFAULT false;

-- 3. ATOMIC & SECURITY DEFINER RPCs FOR GUARANTEED DELETE AND UPDATE

-- 3.1. Delete Invoice Records (Atomic RPC bypassing client RLS restrictions)
CREATE OR REPLACE FUNCTION delete_invoice_records(p_ids TEXT[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT;
BEGIN
    DELETE FROM invoices WHERE id = ANY(p_ids);
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN jsonb_build_object('success', true, 'deleted_count', v_count);
END;
$$;
GRANT EXECUTE ON FUNCTION delete_invoice_records(TEXT[]) TO anon, authenticated, service_role;

-- 3.2. Clear All Invoice Records (Purge History RPC)
CREATE OR REPLACE FUNCTION clear_all_invoice_records()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM invoices;
    RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION clear_all_invoice_records() TO anon, authenticated, service_role;

-- 3.3. Void Invoice Transaction (Safely Marks Invoice Voided and Compensates Khata)
CREATE OR REPLACE FUNCTION void_invoice_transaction(
    p_invoice_number TEXT,
    p_reason TEXT DEFAULT 'Voided by Management',
    p_staff_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_cust_id TEXT;
BEGIN
    SELECT * INTO v_inv FROM invoices WHERE invoice_number = p_invoice_number;

    IF v_inv.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invoice not found: ' || p_invoice_number);
    END IF;

    -- Update invoice to voided state
    UPDATE invoices
    SET is_voided = true,
        void_reason = p_reason
    WHERE invoice_number = p_invoice_number;

    -- Compensating Reversal if Khata Credit was issued
    IF v_inv.credit_amount > 0 THEN
        SELECT id INTO v_cust_id FROM customers WHERE phone = v_inv.customer_phone LIMIT 1;
        IF v_cust_id IS NOT NULL THEN
            INSERT INTO customer_ledger (customer_id, entry_type, amount, reference_type, reference_number, description)
            VALUES (
                v_cust_id,
                'credit',
                v_inv.credit_amount,
                'VOID_REVERSAL',
                'VOID:' || p_invoice_number,
                'Compensating reversal for voided invoice: ' || p_reason
            );

            INSERT INTO ledger_entries (id, customer_id, type, amount, reference_type, reference_number, description, date)
            VALUES (
                'l_' || gen_random_uuid()::text,
                v_cust_id,
                'credit',
                v_inv.credit_amount,
                'VOID_REVERSAL',
                'VOID:' || p_invoice_number,
                'Compensating reversal for voided invoice: ' || p_reason,
                NOW()
            );
        END IF;
    END IF;

    -- Audit Void Log
    BEGIN
        INSERT INTO activity_logs (user_id, action, entity_name, entity_id, details)
        VALUES (
            p_staff_id,
            'VOID_INVOICE',
            'invoices',
            v_inv.id,
            jsonb_build_object(
                'invoice_number', p_invoice_number,
                'reason', p_reason,
                'grand_total', v_inv.grand_total,
                'credit_reversed', v_inv.credit_amount
            )
        );
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_number', p_invoice_number,
        'message', 'Invoice successfully voided and ledger compensated.'
    );
END;
$$;
GRANT EXECUTE ON FUNCTION void_invoice_transaction(TEXT, TEXT, UUID) TO anon, authenticated, service_role;

-- 3.4. Delete Ledger Records
CREATE OR REPLACE FUNCTION delete_ledger_records(p_ids TEXT[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT;
BEGIN
    DELETE FROM ledger_entries WHERE id = ANY(p_ids);
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN jsonb_build_object('success', true, 'deleted_count', v_count);
END;
$$;
GRANT EXECUTE ON FUNCTION delete_ledger_records(TEXT[]) TO anon, authenticated, service_role;

-- 3.5. Delete All Ledger Records for Customer
CREATE OR REPLACE FUNCTION delete_customer_ledger_records(p_customer_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM ledger_entries WHERE customer_id = p_customer_id;
    RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION delete_customer_ledger_records(TEXT) TO anon, authenticated, service_role;

-- 3.6. Update Ledger Record
CREATE OR REPLACE FUNCTION update_ledger_record(
    p_id TEXT,
    p_amount NUMERIC,
    p_type TEXT,
    p_reference_type TEXT,
    p_reference_number TEXT,
    p_description TEXT,
    p_date TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE ledger_entries
    SET amount = p_amount,
        type = p_type,
        reference_type = p_reference_type,
        reference_number = p_reference_number,
        description = p_description,
        date = p_date
    WHERE id = p_id;
    RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION update_ledger_record(TEXT, NUMERIC, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ) TO anon, authenticated, service_role;

-- 4. ROW LEVEL SECURITY (RLS) POLICIES ENABLING FULL DIRECT CRUD
-- Ensures all DELETE and UPDATE queries from authenticated and anonymous restaurant client terminals succeed.

DO $$
BEGIN
    -- invoices
    ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Invoices" ON invoices;
    DROP POLICY IF EXISTS "invoices_select_policy" ON invoices;
    DROP POLICY IF EXISTS "invoices_insert_policy" ON invoices;
    DROP POLICY IF EXISTS "invoices_update_policy" ON invoices;
    DROP POLICY IF EXISTS "invoices_delete_policy" ON invoices;
    CREATE POLICY "Public Access Invoices" ON invoices FOR ALL USING (true) WITH CHECK (true);

    -- ledger_entries
    ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Ledger Entries" ON ledger_entries;
    DROP POLICY IF EXISTS "legacy_ledger_select_policy" ON ledger_entries;
    DROP POLICY IF EXISTS "legacy_ledger_insert_policy" ON ledger_entries;
    DROP POLICY IF EXISTS "legacy_ledger_update_policy" ON ledger_entries;
    DROP POLICY IF EXISTS "legacy_ledger_delete_policy" ON ledger_entries;
    CREATE POLICY "Public Access Ledger Entries" ON ledger_entries FOR ALL USING (true) WITH CHECK (true);

    -- customers
    ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Customers" ON customers;
    DROP POLICY IF EXISTS "customers_select_policy" ON customers;
    DROP POLICY IF EXISTS "customers_write_policy" ON customers;
    CREATE POLICY "Public Access Customers" ON customers FOR ALL USING (true) WITH CHECK (true);

    -- tables
    ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Tables" ON tables;
    DROP POLICY IF EXISTS "tables_select_policy" ON tables;
    DROP POLICY IF EXISTS "tables_insert_policy" ON tables;
    DROP POLICY IF EXISTS "tables_update_policy" ON tables;
    DROP POLICY IF EXISTS "tables_delete_policy" ON tables;
    CREATE POLICY "Public Access Tables" ON tables FOR ALL USING (true) WITH CHECK (true);

    -- menu_items
    ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "Public Read Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "Public Modify Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "items_read_policy" ON menu_items;
    DROP POLICY IF EXISTS "items_write_policy" ON menu_items;
    CREATE POLICY "Public Access Menu Items" ON menu_items FOR ALL USING (true) WITH CHECK (true);

    -- kitchen_tickets
    ALTER TABLE kitchen_tickets ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Kitchen Tickets" ON kitchen_tickets;
    CREATE POLICY "Public Access Kitchen Tickets" ON kitchen_tickets FOR ALL USING (true) WITH CHECK (true);

    -- restaurant_settings
    ALTER TABLE restaurant_settings ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Settings" ON restaurant_settings;
    DROP POLICY IF EXISTS "Public Read Settings" ON restaurant_settings;
    DROP POLICY IF EXISTS "Public Modify Settings" ON restaurant_settings;
    DROP POLICY IF EXISTS "settings_read_policy" ON restaurant_settings;
    DROP POLICY IF EXISTS "settings_write_policy" ON restaurant_settings;
    CREATE POLICY "Public Access Settings" ON restaurant_settings FOR ALL USING (true) WITH CHECK (true);

    -- staff_profiles
    ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Staff Profiles" ON staff_profiles;
    CREATE POLICY "Public Access Staff Profiles" ON staff_profiles FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 5. REALTIME BROADCASTING
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE 
        invoices,
        ledger_entries,
        customers,
        tables,
        menu_items,
        kitchen_tickets,
        restaurant_settings,
        staff_profiles;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
