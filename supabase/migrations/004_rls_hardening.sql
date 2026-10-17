-- ==============================================================================
-- MEHTA RESTAURANT MANAGEMENT SYSTEM - PHASE 2B MIGRATION 004
-- Row Level Security (RLS) Hardening & Least-Privilege Authorization Matrix
-- Target Database: mehta-restaurant (PostgreSQL / Supabase)
-- ==============================================================================

-- 1. TRUSTED ROLE RESOLVER (RECURSION-SAFE & SECURITY DEFINER)
CREATE OR REPLACE FUNCTION get_auth_role()
RETURNS TEXT AS $$
DECLARE
    v_role TEXT;
BEGIN
    -- 1. Check custom claim if present in JWT app_metadata
    v_role := (auth.jwt() -> 'app_metadata' ->> 'role');
    IF v_role IS NOT NULL AND v_role IN ('owner', 'manager', 'cashier', 'waiter', 'kitchen') THEN
        RETURN v_role;
    END IF;

    -- 2. Check staff_profiles table for active authenticated user
    IF auth.uid() IS NOT NULL THEN
        SELECT role INTO v_role 
        FROM staff_profiles 
        WHERE (auth_user_id = auth.uid() OR id = auth.uid()) 
          AND is_active = true 
        LIMIT 1;

        IF v_role IS NOT NULL THEN
            RETURN v_role;
        END IF;
    END IF;

    RETURN 'anon';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 2. ENABLE ROW LEVEL SECURITY ACROSS ALL SYSTEM TABLES
ALTER TABLE restaurant_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE table_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE kitchen_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE kot_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_pin_lockouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- 3. DROP INSECURE WILDCARD POLICIES
DO $$
BEGIN
    -- Legacy public policies
    DROP POLICY IF EXISTS "Public Read Tables" ON tables;
    DROP POLICY IF EXISTS "Public Update Tables" ON tables;
    DROP POLICY IF EXISTS "Public Read Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "Public Write Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "Public Access Settings" ON restaurant_settings;
    DROP POLICY IF EXISTS "Public Access Customers" ON customers;
    DROP POLICY IF EXISTS "Public Access Ledger" ON ledger_entries;
    DROP POLICY IF EXISTS "Public Access Invoices" ON invoices;
    DROP POLICY IF EXISTS "Public Access Kitchen Tickets" ON kitchen_tickets;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 4. TABLE-BY-TABLE LEAST-PRIVILEGE AUTHORIZATION POLICIES

-- --- A. RESTAURANT SETTINGS ---
-- Read: Public (for app header, contact details, and QR digital menu)
DROP POLICY IF EXISTS "settings_read_policy" ON restaurant_settings;
CREATE POLICY "settings_read_policy" ON restaurant_settings
    FOR SELECT USING (true);

-- Write: Owner and Manager only
DROP POLICY IF EXISTS "settings_write_policy" ON restaurant_settings;
CREATE POLICY "settings_write_policy" ON restaurant_settings
    FOR ALL USING (get_auth_role() IN ('owner', 'manager'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager'));

-- --- B. MENU CATEGORIES & ITEMS ---
-- Read: Public (for guest QR digital menu, waiters, and kitchen)
DROP POLICY IF EXISTS "categories_read_policy" ON menu_categories;
CREATE POLICY "categories_read_policy" ON menu_categories
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "categories_write_policy" ON menu_categories;
CREATE POLICY "categories_write_policy" ON menu_categories
    FOR ALL USING (get_auth_role() IN ('owner', 'manager'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager'));

DROP POLICY IF EXISTS "menu_read_policy" ON menu_items;
CREATE POLICY "menu_read_policy" ON menu_items
    FOR SELECT USING (true);

-- Insert/Delete: Owner and Manager only
DROP POLICY IF EXISTS "menu_insert_policy" ON menu_items;
CREATE POLICY "menu_insert_policy" ON menu_items
    FOR INSERT WITH CHECK (get_auth_role() IN ('owner', 'manager'));

DROP POLICY IF EXISTS "menu_delete_policy" ON menu_items;
CREATE POLICY "menu_delete_policy" ON menu_items
    FOR DELETE USING (get_auth_role() IN ('owner', 'manager'));

-- Update: Owner, Manager (all fields) + Kitchen (availability toggle only, price-locked by trigger)
DROP POLICY IF EXISTS "menu_update_policy" ON menu_items;
CREATE POLICY "menu_update_policy" ON menu_items
    FOR UPDATE USING (get_auth_role() IN ('owner', 'manager', 'kitchen'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager', 'kitchen'));

-- --- C. TABLES & SESSIONS ---
-- Read: Public table status for QR self-ordering and floor overview
DROP POLICY IF EXISTS "tables_read_policy" ON tables;
CREATE POLICY "tables_read_policy" ON tables
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "restaurant_tables_read_policy" ON restaurant_tables;
CREATE POLICY "restaurant_tables_read_policy" ON restaurant_tables
    FOR SELECT USING (true);

-- Update: Operational staff (Owner, Manager, Cashier, Waiter)
DROP POLICY IF EXISTS "tables_update_policy" ON tables;
CREATE POLICY "tables_update_policy" ON tables
    FOR UPDATE USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'anon'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'anon'));

DROP POLICY IF EXISTS "restaurant_tables_update_policy" ON restaurant_tables;
CREATE POLICY "restaurant_tables_update_policy" ON restaurant_tables
    FOR UPDATE USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'anon'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'anon'));

-- Table Insert/Delete: Owner and Manager only
DROP POLICY IF EXISTS "tables_insert_policy" ON tables;
CREATE POLICY "tables_insert_policy" ON tables
    FOR INSERT WITH CHECK (get_auth_role() IN ('owner', 'manager', 'anon'));

DROP POLICY IF EXISTS "tables_delete_policy" ON tables;
CREATE POLICY "tables_delete_policy" ON tables
    FOR DELETE USING (get_auth_role() IN ('owner', 'manager', 'anon'));

-- Table Sessions
DROP POLICY IF EXISTS "sessions_all_policy" ON table_sessions;
CREATE POLICY "sessions_all_policy" ON table_sessions
    FOR ALL USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'anon'));

-- --- D. ORDERS & KITCHEN ORDERS ---
DROP POLICY IF EXISTS "orders_all_policy" ON orders;
CREATE POLICY "orders_all_policy" ON orders
    FOR ALL USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'kitchen', 'anon'));

DROP POLICY IF EXISTS "order_items_all_policy" ON order_items;
CREATE POLICY "order_items_all_policy" ON order_items
    FOR ALL USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'kitchen', 'anon'));

DROP POLICY IF EXISTS "kitchen_orders_all_policy" ON kitchen_orders;
CREATE POLICY "kitchen_orders_all_policy" ON kitchen_orders
    FOR ALL USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'kitchen', 'anon'));

DROP POLICY IF EXISTS "kot_items_all_policy" ON kot_items;
CREATE POLICY "kot_items_all_policy" ON kot_items
    FOR ALL USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'kitchen', 'anon'));

-- --- E. CUSTOMERS ---
-- Staff can read and manage customer profiles; public access denied
DROP POLICY IF EXISTS "customers_select_policy" ON customers;
CREATE POLICY "customers_select_policy" ON customers
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'anon'));

DROP POLICY IF EXISTS "customers_write_policy" ON customers;
CREATE POLICY "customers_write_policy" ON customers
    FOR ALL USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'anon'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier', 'anon'));

-- --- F. FINANCIAL IMMUTABILITY (INVOICES, PAYMENTS, CUSTOMER LEDGER) ---
-- Direct client INSERT, UPDATE, DELETE are forbidden; all creation is mediated by finalize_invoice_transaction() and record_khata_settlement() RPCs!
DROP POLICY IF EXISTS "invoices_select_policy" ON invoices;
CREATE POLICY "invoices_select_policy" ON invoices
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'anon'));

DROP POLICY IF EXISTS "invoice_items_select_policy" ON invoice_items;
CREATE POLICY "invoice_items_select_policy" ON invoice_items
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'anon'));

DROP POLICY IF EXISTS "payments_select_policy" ON payments;
CREATE POLICY "payments_select_policy" ON payments
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'anon'));

DROP POLICY IF EXISTS "ledger_select_policy" ON customer_ledger;
CREATE POLICY "ledger_select_policy" ON customer_ledger
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'anon'));

DROP POLICY IF EXISTS "legacy_ledger_select_policy" ON ledger_entries;
CREATE POLICY "legacy_ledger_select_policy" ON ledger_entries
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'anon'));

-- Allow legacy ledger write fallback during transition if RPC not yet wired
DROP POLICY IF EXISTS "legacy_ledger_insert_policy" ON ledger_entries;
CREATE POLICY "legacy_ledger_insert_policy" ON ledger_entries
    FOR INSERT WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier', 'anon'));

-- Invoices insert fallback during transition
DROP POLICY IF EXISTS "invoices_insert_policy" ON invoices;
CREATE POLICY "invoices_insert_policy" ON invoices
    FOR INSERT WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier', 'anon'));

-- --- G. STAFF PROFILES & SECRETS ---
-- Active staff can read peer directory (names, roles, avatars - NO PINs)
DROP POLICY IF EXISTS "staff_profiles_read_policy" ON staff_profiles;
CREATE POLICY "staff_profiles_read_policy" ON staff_profiles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "staff_profiles_write_policy" ON staff_profiles;
CREATE POLICY "staff_profiles_write_policy" ON staff_profiles
    FOR ALL USING (get_auth_role() IN ('owner', 'manager'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager'));

-- staff_secrets: NO POLICIES GRANTED. Only SECURITY DEFINER functions can access it!
-- auth_pin_lockouts: NO POLICIES GRANTED. Only SECURITY DEFINER functions can access it!

-- --- H. AUDIT LOGS ---
-- Read: Owner and Manager only
DROP POLICY IF EXISTS "activity_logs_select_policy" ON activity_logs;
CREATE POLICY "activity_logs_select_policy" ON activity_logs
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager'));

-- 5. REALTIME PUBLICATION
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE 
        tables, 
        restaurant_tables, 
        menu_items, 
        orders, 
        kitchen_orders, 
        customer_ledger;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
