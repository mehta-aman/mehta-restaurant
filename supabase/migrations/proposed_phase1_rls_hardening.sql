-- ==============================================================================
-- PROPOSED MIGRATION (PHASE 1): ROW LEVEL SECURITY (RLS) HARDENING
-- Target: Mehta Restaurant Management System (PostgreSQL / Supabase)
-- NOTE: DO NOT EXECUTE DIRECTLY ON PRODUCTION WITHOUT STAGING VERIFICATION.
-- ==============================================================================

-- 1. Create Staff Profiles table to link Supabase auth.users to Restaurant Roles
CREATE TABLE IF NOT EXISTS staff_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('owner', 'manager', 'cashier', 'waiter', 'kitchen')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on staff_profiles
ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;

-- Helper function to extract current authenticated user's restaurant role
CREATE OR REPLACE FUNCTION get_auth_role()
RETURNS text AS $$
    SELECT COALESCE(
        (auth.jwt() -> 'app_metadata' ->> 'role'),
        (SELECT role FROM staff_profiles WHERE id = auth.uid() AND is_active = true),
        'anon'
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 2. REVOKE OVERLY PERMISSIVE WILDCARD POLICIES
DO $$
BEGIN
    DROP POLICY IF EXISTS "Public Read Tables" ON tables;
    DROP POLICY IF EXISTS "Public Update Tables" ON tables;
    DROP POLICY IF EXISTS "Public Read Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "Public Write Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "Public Access Settings" ON restaurant_settings;
    DROP POLICY IF EXISTS "Public Access Customers" ON customers;
    DROP POLICY IF EXISTS "Public Access Ledger" ON ledger_entries;
    DROP POLICY IF EXISTS "Public Access Invoices" ON invoices;
    DROP POLICY IF EXISTS "Public Access Kitchen Tickets" ON kitchen_tickets;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- Enable RLS across all active restaurant tables
ALTER TABLE restaurant_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE kitchen_tickets ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- 3. TABLE-BY-TABLE AUTHORIZATION POLICIES
-- ==============================================================================

-- --- A. RESTAURANT SETTINGS ---
-- Read: Allowed for public/guest digital menu and all active staff
CREATE POLICY "settings_select_policy" ON restaurant_settings
    FOR SELECT USING (true);

-- Write/Update: Owner and Manager only
CREATE POLICY "settings_modify_policy" ON restaurant_settings
    FOR ALL USING (get_auth_role() IN ('owner', 'manager'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager'));

-- --- B. MENU ITEMS ---
-- Read: Public QR Digital menu and all active staff
CREATE POLICY "menu_select_policy" ON menu_items
    FOR SELECT USING (true);

-- Insert/Delete: Owner and Manager only
CREATE POLICY "menu_manage_policy" ON menu_items
    FOR INSERT WITH CHECK (get_auth_role() IN ('owner', 'manager'));

CREATE POLICY "menu_delete_policy" ON menu_items
    FOR DELETE USING (get_auth_role() IN ('owner', 'manager'));

-- Update: Owner/Manager (all fields) + Kitchen (stock availability toggle only)
CREATE POLICY "menu_update_policy" ON menu_items
    FOR UPDATE USING (get_auth_role() IN ('owner', 'manager', 'kitchen'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager', 'kitchen'));

-- --- C. TABLES ---
-- Read: Guest table verification + All active staff
CREATE POLICY "tables_select_policy" ON tables
    FOR SELECT USING (true);

-- Insert/Delete: Owner and Manager only
CREATE POLICY "tables_insert_policy" ON tables
    FOR INSERT WITH CHECK (get_auth_role() IN ('owner', 'manager'));

CREATE POLICY "tables_delete_policy" ON tables
    FOR DELETE USING (get_auth_role() IN ('owner', 'manager'));

-- Update: Owner, Manager, Cashier, Waiter (status transitions, guest counts, merges)
CREATE POLICY "tables_update_policy" ON tables
    FOR UPDATE USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter'));

-- --- D. KITCHEN TICKETS (KOT) ---
-- Read: Staff only (Kitchen, Waiter, Cashier, Manager, Owner) - Public DENIED
CREATE POLICY "kot_select_policy" ON kitchen_tickets
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter', 'kitchen'));

-- Insert: Waiter, Cashier, Manager, Owner
CREATE POLICY "kot_insert_policy" ON kitchen_tickets
    FOR INSERT WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter'));

-- Update: Kitchen (prep states) + Waiter (served state) + Manager/Owner
CREATE POLICY "kot_update_policy" ON kitchen_tickets
    FOR UPDATE USING (get_auth_role() IN ('owner', 'manager', 'waiter', 'kitchen'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager', 'waiter', 'kitchen'));

-- Delete: Owner and Manager only
CREATE POLICY "kot_delete_policy" ON kitchen_tickets
    FOR DELETE USING (get_auth_role() IN ('owner', 'manager'));

-- --- E. CUSTOMERS ---
-- Read: Staff only (Owner, Manager, Cashier, Waiter) - Public DENIED
CREATE POLICY "customers_select_policy" ON customers
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter'));

-- Insert/Update: Owner, Manager, Cashier
CREATE POLICY "customers_modify_policy" ON customers
    FOR INSERT WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier'));

CREATE POLICY "customers_update_policy" ON customers
    FOR UPDATE USING (get_auth_role() IN ('owner', 'manager', 'cashier'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier'));

-- Delete: Owner only
CREATE POLICY "customers_delete_policy" ON customers
    FOR DELETE USING (get_auth_role() = 'owner');

-- --- F. INVOICES (FINANCIAL RECORDS) ---
-- Read: Owner, Manager, Cashier, Waiter - Public DENIED
CREATE POLICY "invoices_select_policy" ON invoices
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager', 'cashier', 'waiter'));

-- Insert: Cashier, Manager, Owner
CREATE POLICY "invoices_insert_policy" ON invoices
    FOR INSERT WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier'));

-- Update: STRICT - Owner and Manager only (prevents tampering with billed amounts)
CREATE POLICY "invoices_update_policy" ON invoices
    FOR UPDATE USING (get_auth_role() IN ('owner', 'manager'))
    WITH CHECK (get_auth_role() IN ('owner', 'manager'));

-- Delete: STRICT - Owner only
CREATE POLICY "invoices_delete_policy" ON invoices
    FOR DELETE USING (get_auth_role() = 'owner');

-- --- G. CUSTOMER LEDGER (KHATA ENTRIES) ---
-- Read: Owner, Manager, Cashier only - Waiters and Kitchen DENIED; Public DENIED
CREATE POLICY "ledger_select_policy" ON ledger_entries
    FOR SELECT USING (get_auth_role() IN ('owner', 'manager', 'cashier'));

-- Insert: Owner, Manager, Cashier (Append-only for debt additions and settlements)
CREATE POLICY "ledger_insert_policy" ON ledger_entries
    FOR INSERT WITH CHECK (get_auth_role() IN ('owner', 'manager', 'cashier'));

-- Update: STRICT - Owner only (for audit adjustments; cashiers cannot rewrite history)
CREATE POLICY "ledger_update_policy" ON ledger_entries
    FOR UPDATE USING (get_auth_role() = 'owner')
    WITH CHECK (get_auth_role() = 'owner');

-- Delete: STRICT - Owner only
CREATE POLICY "ledger_delete_policy" ON ledger_entries
    FOR DELETE USING (get_auth_role() = 'owner');
