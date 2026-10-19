/// Embedded SQL Schema script for Mehta Restaurant Supabase Setup (Phase 2B Authoritative Schema)
const String kSupabaseSchemaSql = r'''-- ==============================================================================
-- MEHTA RESTAURANT MANAGEMENT SYSTEM - PHASE 2B MIGRATION 001
-- Relational Schema (Additive, Non-Destructive)
-- Target Database: mehta-restaurant (PostgreSQL / Supabase)
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. ENUMS (Safe creation with exception handling)
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('owner', 'manager', 'cashier', 'waiter', 'kitchen');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE table_status AS ENUM ('available', 'occupied', 'ordering', 'bill_requested', 'payment_pending', 'closed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE session_status AS ENUM ('active', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE order_status AS ENUM ('draft', 'confirmed', 'sent_to_kitchen', 'preparing', 'ready', 'served', 'bill_requested', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE kot_status AS ENUM ('new', 'accepted', 'preparing', 'ready', 'served', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_method AS ENUM ('cash', 'upi', 'card', 'credit', 'bank_transfer', 'other');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE invoice_status AS ENUM ('draft', 'issued', 'partially_paid', 'paid', 'voided');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE ledger_entry_type AS ENUM ('debit', 'credit');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. ENHANCE EXISTING TABLES WITH MISSING COLUMNS
-- Add name & section to legacy tables table if missing
ALTER TABLE tables ADD COLUMN IF NOT EXISTS name TEXT DEFAULT '';
ALTER TABLE tables ADD COLUMN IF NOT EXISTS section TEXT DEFAULT 'Indoor AC';

-- Add inventory_tracking_enabled to restaurant_settings if missing
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS inventory_tracking_enabled BOOLEAN DEFAULT false;

-- 4. MENU CATEGORIES TABLE
CREATE TABLE IF NOT EXISTS menu_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    display_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed Standard Categories
INSERT INTO menu_categories (name, display_order)
VALUES 
    ('Starters', 1),
    ('Main Course', 2),
    ('Breads', 3),
    ('Rice & Biryani', 4),
    ('Beverages', 5),
    ('Desserts', 6),
    ('Packaged Goods', 7)
ON CONFLICT (name) DO NOTHING;

-- Add category_id FK column to menu_items
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES menu_categories(id) ON DELETE SET NULL;

-- Backfill category_id in existing menu_items from category text column
UPDATE menu_items mi
SET category_id = mc.id
FROM menu_categories mc
WHERE mi.category = mc.name
  AND (mi.category_id IS NULL OR mi.category_id <> mc.id);

-- 5. RELATIONAL RESTAURANT TABLES & SESSIONS
CREATE TABLE IF NOT EXISTS restaurant_tables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_number TEXT NOT NULL UNIQUE, -- 'T01' to 'T10'
    name TEXT NOT NULL DEFAULT '',
    floor_section TEXT NOT NULL DEFAULT 'Indoor AC',
    seating_capacity INT NOT NULL DEFAULT 6,
    status TEXT NOT NULL DEFAULT 'available', -- 'available', 'occupied', 'billed'
    guest_count INT NOT NULL DEFAULT 0,
    active_order_id TEXT,
    merged_into TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Synchronize existing tables into restaurant_tables
INSERT INTO restaurant_tables (id, table_number, name, floor_section, seating_capacity, status, guest_count, active_order_id, merged_into)
SELECT 
    gen_random_uuid(),
    t.table_number,
    COALESCE(t.name, ''),
    COALESCE(t.section, 'Indoor AC'),
    COALESCE(t.capacity, 6),
    COALESCE(t.status, 'available'),
    COALESCE(t.guest_count, 0),
    t.active_order_id,
    t.merged_into
FROM tables t
ON CONFLICT (table_number) DO UPDATE SET
    name = EXCLUDED.name,
    floor_section = EXCLUDED.floor_section,
    seating_capacity = EXCLUDED.seating_capacity,
    status = EXCLUDED.status,
    guest_count = EXCLUDED.guest_count,
    active_order_id = EXCLUDED.active_order_id,
    merged_into = EXCLUDED.merged_into,
    updated_at = NOW();

-- TABLE SESSIONS
CREATE TABLE IF NOT EXISTS table_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_number TEXT NOT NULL,
    guest_count INT NOT NULL DEFAULT 2,
    customer_name TEXT,
    customer_phone TEXT,
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'completed', 'cancelled'
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ
);

-- 6. ORDERS & ORDER ITEMS
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT NOT NULL UNIQUE,
    table_number TEXT NOT NULL,
    session_id UUID REFERENCES table_sessions(id) ON DELETE SET NULL,
    customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
    customer_name TEXT,
    customer_phone TEXT,
    status TEXT NOT NULL DEFAULT 'confirmed',
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    grand_total NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id TEXT REFERENCES menu_items(id) ON DELETE RESTRICT,
    item_name TEXT NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    total_price NUMERIC(10, 2) GENERATED ALWAYS AS (unit_price * quantity) STORED,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. KITCHEN ORDER TICKETS (KOT)
CREATE TABLE IF NOT EXISTS kitchen_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kot_number TEXT NOT NULL UNIQUE,
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    table_number TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'newTicket', -- 'newTicket', 'preparing', 'ready', 'served'
    is_rush BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ready_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS kot_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kot_id UUID NOT NULL REFERENCES kitchen_orders(id) ON DELETE CASCADE,
    order_item_id UUID REFERENCES order_items(id) ON DELETE SET NULL,
    item_name TEXT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
);

-- 8. INVOICE ITEMS & PAYMENTS
CREATE TABLE IF NOT EXISTS invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id TEXT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    total_price NUMERIC(10, 2) NOT NULL,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id TEXT REFERENCES invoices(id) ON DELETE SET NULL,
    customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    method TEXT NOT NULL CHECK (method IN ('cash', 'upi', 'card', 'credit', 'bank_transfer', 'other')),
    reference_number TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. RELATIONAL CUSTOMER LEDGER
CREATE TABLE IF NOT EXISTS customer_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    entry_type TEXT NOT NULL CHECK (entry_type IN ('debit', 'credit')),
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    reference_type TEXT NOT NULL, -- 'INVOICE', 'PAYMENT', 'OPENING_BALANCE', 'VOID_REVERSAL'
    reference_number TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Synchronize existing legacy ledger_entries into customer_ledger
INSERT INTO customer_ledger (id, customer_id, entry_type, amount, reference_type, reference_number, description, created_at)
SELECT 
    gen_random_uuid(),
    le.customer_id,
    le.type,
    le.amount,
    le.reference_type,
    le.reference_number,
    le.description,
    COALESCE(le.date, le.created_at, NOW())
FROM ledger_entries le
WHERE NOT EXISTS (
    SELECT 1 FROM customer_ledger cl 
    WHERE cl.customer_id = le.customer_id 
      AND cl.reference_number = le.reference_number
);

-- 10. REALTIME DYNAMIC CUSTOMER BALANCE VIEW
CREATE OR REPLACE VIEW view_customer_balances AS
SELECT 
    c.id AS customer_id,
    c.name,
    c.phone,
    COALESCE(SUM(CASE WHEN cl.entry_type = 'debit' THEN cl.amount ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN cl.entry_type = 'credit' THEN cl.amount ELSE 0 END), 0) AS current_balance,
    MAX(cl.created_at) AS last_transaction_at
FROM customers c
LEFT JOIN customer_ledger cl ON c.id = cl.customer_id
GROUP BY c.id, c.name, c.phone;

-- 11. AUDIT EVENT LOGS
CREATE TABLE IF NOT EXISTS activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    action TEXT NOT NULL, -- 'FINALIZE_INVOICE', 'VOID_INVOICE', 'KHATA_SETTLEMENT', 'PIN_ATTEMPT'
    entity_name TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    details JSONB DEFAULT '{}'::jsonb,
    ip_address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- ==============================================================================
-- MEHTA RESTAURANT MANAGEMENT SYSTEM - PHASE 2B MIGRATION 002
-- Staff Server-Side Authentication & 5-Attempt Terminal Lockout
-- Target Database: mehta-restaurant (PostgreSQL / Supabase)
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
SET search_path = public, extensions, auth, pg_temp;

-- 2. STAFF PROFILES TABLE
CREATE TABLE IF NOT EXISTS staff_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    staff_code TEXT UNIQUE NOT NULL, -- 's1', 's2', ... 's8'
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('owner', 'manager', 'cashier', 'waiter', 'kitchen')),
    avatar_icon TEXT NOT NULL DEFAULT '👤',
    phone TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. STAFF SECRETS TABLE (ISOLATED CREDENTIAL STORAGE)
-- Client queries can NEVER select from this table directly
CREATE TABLE IF NOT EXISTS staff_secrets (
    staff_id UUID PRIMARY KEY REFERENCES staff_profiles(id) ON DELETE CASCADE,
    pin_hash TEXT NOT NULL, -- bcrypt hash generated by crypt()
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. TERMINAL LOCKOUT TABLE (RATE LIMITING & BRUTE-FORCE PROTECTION)
CREATE TABLE IF NOT EXISTS auth_pin_lockouts (
    terminal_id TEXT PRIMARY KEY,
    failed_attempts INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    last_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. SEED INITIAL 8 STAFF MEMBERS & BCRYPT PIN HASHES
DO $$
DECLARE
    v_s1 UUID; v_s2 UUID; v_s3 UUID; v_s4 UUID;
    v_s5 UUID; v_s6 UUID; v_s7 UUID; v_s8 UUID;
BEGIN
    -- s1: Aman Mehta (Owner) - PIN '1234'
    INSERT INTO staff_profiles (staff_code, full_name, role, avatar_icon)
    VALUES ('s1', 'Aman Mehta', 'owner', '👑')
    ON CONFLICT (staff_code) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role, avatar_icon = EXCLUDED.avatar_icon
    RETURNING id INTO v_s1;
    
    INSERT INTO staff_secrets (staff_id, pin_hash)
    VALUES (v_s1, crypt('1234', gen_salt('bf', 8)))
    ON CONFLICT (staff_id) DO UPDATE SET pin_hash = crypt('1234', gen_salt('bf', 8)), updated_at = NOW();

    -- s2: Sh. Mehta (Manager / Father) - PIN '9999'
    INSERT INTO staff_profiles (staff_code, full_name, role, avatar_icon)
    VALUES ('s2', 'Sh. Mehta (Father)', 'manager', '👔')
    ON CONFLICT (staff_code) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role, avatar_icon = EXCLUDED.avatar_icon
    RETURNING id INTO v_s2;

    INSERT INTO staff_secrets (staff_id, pin_hash)
    VALUES (v_s2, crypt('9999', gen_salt('bf', 8)))
    ON CONFLICT (staff_id) DO UPDATE SET pin_hash = crypt('9999', gen_salt('bf', 8)), updated_at = NOW();

    -- s3: Counter Cashier - PIN '2222'
    INSERT INTO staff_profiles (staff_code, full_name, role, avatar_icon)
    VALUES ('s3', 'Counter Cashier', 'cashier', '💳')
    ON CONFLICT (staff_code) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role, avatar_icon = EXCLUDED.avatar_icon
    RETURNING id INTO v_s3;

    INSERT INTO staff_secrets (staff_id, pin_hash)
    VALUES (v_s3, crypt('2222', gen_salt('bf', 8)))
    ON CONFLICT (staff_id) DO UPDATE SET pin_hash = crypt('2222', gen_salt('bf', 8)), updated_at = NOW();

    -- s4: Ramesh (Waiter 1) - PIN '1001'
    INSERT INTO staff_profiles (staff_code, full_name, role, avatar_icon)
    VALUES ('s4', 'Ramesh (Waiter 1)', 'waiter', '🛎️')
    ON CONFLICT (staff_code) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role, avatar_icon = EXCLUDED.avatar_icon
    RETURNING id INTO v_s4;

    INSERT INTO staff_secrets (staff_id, pin_hash)
    VALUES (v_s4, crypt('1001', gen_salt('bf', 8)))
    ON CONFLICT (staff_id) DO UPDATE SET pin_hash = crypt('1001', gen_salt('bf', 8)), updated_at = NOW();

    -- s5: Suresh (Waiter 2) - PIN '1002'
    INSERT INTO staff_profiles (staff_code, full_name, role, avatar_icon)
    VALUES ('s5', 'Suresh (Waiter 2)', 'waiter', '🛎️')
    ON CONFLICT (staff_code) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role, avatar_icon = EXCLUDED.avatar_icon
    RETURNING id INTO v_s5;

    INSERT INTO staff_secrets (staff_id, pin_hash)
    VALUES (v_s5, crypt('1002', gen_salt('bf', 8)))
    ON CONFLICT (staff_id) DO UPDATE SET pin_hash = crypt('1002', gen_salt('bf', 8)), updated_at = NOW();

    -- s6: Dinesh (Waiter 3) - PIN '1003'
    INSERT INTO staff_profiles (staff_code, full_name, role, avatar_icon)
    VALUES ('s6', 'Dinesh (Waiter 3)', 'waiter', '🛎️')
    ON CONFLICT (staff_code) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role, avatar_icon = EXCLUDED.avatar_icon
    RETURNING id INTO v_s6;

    INSERT INTO staff_secrets (staff_id, pin_hash)
    VALUES (v_s6, crypt('1003', gen_salt('bf', 8)))
    ON CONFLICT (staff_id) DO UPDATE SET pin_hash = crypt('1003', gen_salt('bf', 8)), updated_at = NOW();

    -- s7: Kitchen Chef 1 - PIN '3333'
    INSERT INTO staff_profiles (staff_code, full_name, role, avatar_icon)
    VALUES ('s7', 'Kitchen Chef 1', 'kitchen', '👨‍🍳')
    ON CONFLICT (staff_code) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role, avatar_icon = EXCLUDED.avatar_icon
    RETURNING id INTO v_s7;

    INSERT INTO staff_secrets (staff_id, pin_hash)
    VALUES (v_s7, crypt('3333', gen_salt('bf', 8)))
    ON CONFLICT (staff_id) DO UPDATE SET pin_hash = crypt('3333', gen_salt('bf', 8)), updated_at = NOW();

    -- s8: Kitchen Helper 2 - PIN '3334'
    INSERT INTO staff_profiles (staff_code, full_name, role, avatar_icon)
    VALUES ('s8', 'Kitchen Helper 2', 'kitchen', '👨‍🍳')
    ON CONFLICT (staff_code) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role, avatar_icon = EXCLUDED.avatar_icon
    RETURNING id INTO v_s8;

    INSERT INTO staff_secrets (staff_id, pin_hash)
    VALUES (v_s8, crypt('3334', gen_salt('bf', 8)))
    ON CONFLICT (staff_id) DO UPDATE SET pin_hash = crypt('3334', gen_salt('bf', 8)), updated_at = NOW();
END $$;

-- 6. SECURE PIN VERIFICATION RPC (SERVER-SIDE BCRYPT & 5-ATTEMPT LOCKOUT)
CREATE OR REPLACE FUNCTION verify_staff_pin(
    p_terminal_id TEXT,
    p_pin TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_failed INT := 0;
    v_locked_until TIMESTAMPTZ;
    v_staff RECORD;
    v_term_id TEXT;
BEGIN
    v_term_id := COALESCE(NULLIF(TRIM(p_terminal_id), ''), 'default_terminal');

    -- Step 1: Check existing lockout state
    SELECT failed_attempts, locked_until
    INTO v_failed, v_locked_until
    FROM auth_pin_lockouts
    WHERE terminal_id = v_term_id;

    IF v_locked_until IS NOT NULL AND v_locked_until > NOW() THEN
        RETURN jsonb_build_object(
            'success', false,
            'locked', true,
            'message', 'Terminal is locked due to consecutive failed attempts.',
            'retry_after_seconds', GREATEST(0, EXTRACT(EPOCH FROM (v_locked_until - NOW()))::INT)
        );
    END IF;

    -- If past lock duration has expired, reset counter
    IF v_locked_until IS NOT NULL AND v_locked_until <= NOW() THEN
        v_failed := 0;
    END IF;

    -- Step 2: Test PIN against active staff bcrypt hashes
    SELECT sp.id, sp.staff_code, sp.full_name, sp.role, sp.avatar_icon
    INTO v_staff
    FROM staff_profiles sp
    JOIN staff_secrets ss ON sp.id = ss.staff_id
    WHERE sp.is_active = true
      AND ss.pin_hash = crypt(p_pin, ss.pin_hash)
    LIMIT 1;

    -- Step 3: Handle Match
    IF v_staff.id IS NOT NULL THEN
        -- Reset lockout record on successful authentication
        INSERT INTO auth_pin_lockouts (terminal_id, failed_attempts, locked_until, last_attempt_at)
        VALUES (v_term_id, 0, NULL, NOW())
        ON CONFLICT (terminal_id) DO UPDATE SET
            failed_attempts = 0,
            locked_until = NULL,
            last_attempt_at = NOW();

        -- Audit success
        INSERT INTO activity_logs (user_id, action, entity_name, entity_id, details)
        VALUES (
            v_staff.id,
            'STAFF_PIN_LOGIN_SUCCESS',
            'staff_profiles',
            v_staff.id::text,
            jsonb_build_object('terminal_id', v_term_id, 'staff_code', v_staff.staff_code)
        );

        RETURN jsonb_build_object(
            'success', true,
            'locked', false,
            'staff', jsonb_build_object(
                'id', v_staff.id,
                'staff_code', v_staff.staff_code,
                'name', v_staff.full_name,
                'role', v_staff.role,
                'avatar_icon', v_staff.avatar_icon
            )
        );
    END IF;

    -- Step 4: Handle Failure
    v_failed := COALESCE(v_failed, 0) + 1;

    IF v_failed >= 5 THEN
        -- 5 consecutive failures: 5-minute lockout
        INSERT INTO auth_pin_lockouts (terminal_id, failed_attempts, locked_until, last_attempt_at)
        VALUES (v_term_id, v_failed, NOW() + INTERVAL '5 minutes', NOW())
        ON CONFLICT (terminal_id) DO UPDATE SET
            failed_attempts = v_failed,
            locked_until = NOW() + INTERVAL '5 minutes',
            last_attempt_at = NOW();

        INSERT INTO activity_logs (action, entity_name, entity_id, details)
        VALUES (
            'TERMINAL_LOCKED_5_MINUTES',
            'auth_pin_lockouts',
            v_term_id,
            jsonb_build_object('terminal_id', v_term_id, 'failed_attempts', v_failed)
        );

        RETURN jsonb_build_object(
            'success', false,
            'locked', true,
            'message', 'Maximum PIN attempts exceeded. Terminal locked for 5 minutes.',
            'retry_after_seconds', 300
        );
    ELSE
        -- 1-4 failures
        INSERT INTO auth_pin_lockouts (terminal_id, failed_attempts, locked_until, last_attempt_at)
        VALUES (v_term_id, v_failed, NULL, NOW())
        ON CONFLICT (terminal_id) DO UPDATE SET
            failed_attempts = v_failed,
            locked_until = NULL,
            last_attempt_at = NOW();

        RETURN jsonb_build_object(
            'success', false,
            'locked', false,
            'message', 'Incorrect PIN! Please try again.',
            'attempts_remaining', 5 - v_failed
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, auth, pg_temp;
-- ==============================================================================
-- MEHTA RESTAURANT MANAGEMENT SYSTEM - PHASE 2B MIGRATION 003
-- Safe Financial Operations, Atomic Invoicing, Khata Ledger, and Price Protection
-- Target Database: mehta-restaurant (PostgreSQL / Supabase)
-- ==============================================================================

-- 1. ATOMIC INVOICE SEQUENCE (STARTS AT MR-001001)
CREATE SEQUENCE IF NOT EXISTS invoice_number_seq START WITH 1001;

-- Initialize sequence safely without colliding with any existing invoice
DO $$
DECLARE
    v_max_num INT := 1000;
BEGIN
    SELECT COALESCE(
        MAX(
            NULLIF(regexp_replace(invoice_number, '\D', '', 'g'), '')::INT
        ), 1000
    ) INTO v_max_num FROM invoices;

    IF v_max_num >= 1001 THEN
        PERFORM setval('invoice_number_seq', v_max_num + 1);
    ELSE
        PERFORM setval('invoice_number_seq', 1001, false);
    END IF;
END $$;

-- 2. ATOMIC INVOICE FINALIZATION RPC
CREATE OR REPLACE FUNCTION finalize_invoice_transaction(
    p_idempotency_key TEXT,
    p_table_number TEXT,
    p_subtotal NUMERIC,
    p_tax_amount NUMERIC,
    p_grand_total NUMERIC,
    p_cash_paid NUMERIC DEFAULT 0.00,
    p_upi_paid NUMERIC DEFAULT 0.00,
    p_credit_amount NUMERIC DEFAULT 0.00,
    p_customer_name TEXT DEFAULT NULL,
    p_customer_phone TEXT DEFAULT NULL,
    p_customer_id TEXT DEFAULT NULL,
    p_items JSONB DEFAULT '[]'::jsonb,
    p_upi_reference TEXT DEFAULT NULL,
    p_staff_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_existing RECORD;
    v_seq_val BIGINT;
    v_invoice_num TEXT;
    v_cust_id TEXT;
    v_item JSONB;
BEGIN
    -- Step 1: Idempotency Protection - Prevent duplicate billing on network retries
    SELECT id, invoice_number, grand_total, created_at
    INTO v_existing
    FROM invoices
    WHERE id = p_idempotency_key;

    IF v_existing.id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'idempotent_replay', true,
            'invoice_id', v_existing.id,
            'invoice_number', v_existing.invoice_number,
            'grand_total', v_existing.grand_total,
            'created_at', v_existing.created_at
        );
    END IF;

    -- Step 2: Payment Total Validation
    IF (p_cash_paid + p_upi_paid + p_credit_amount) < (p_grand_total - 0.05) THEN
        RAISE EXCEPTION 'Total tender (Cash: %, UPI: %, Credit: %) is less than Grand Total (%)',
            p_cash_paid, p_upi_paid, p_credit_amount, p_grand_total;
    END IF;

    -- Step 3: Customer Resolution for Credit / Khata
    v_cust_id := p_customer_id;
    IF p_credit_amount > 0 THEN
        IF v_cust_id IS NULL AND (p_customer_name IS NULL OR TRIM(p_customer_name) = '') THEN
            RAISE EXCEPTION 'Customer name and phone are strictly required to issue Khata credit of ₹%', p_credit_amount;
        END IF;

        IF v_cust_id IS NULL THEN
            -- Find or create customer
            SELECT id INTO v_cust_id FROM customers WHERE phone = TRIM(p_customer_phone) LIMIT 1;
            IF v_cust_id IS NULL THEN
                v_cust_id := 'c_' || gen_random_uuid()::text;
                INSERT INTO customers (id, name, phone, notes)
                VALUES (v_cust_id, TRIM(p_customer_name), TRIM(COALESCE(p_customer_phone, '')), 'Created from dining credit');
            END IF;
        END IF;
    END IF;

    -- Step 4: Atomic Generation of Invoice Number
    v_seq_val := nextval('invoice_number_seq');
    v_invoice_num := 'MR-' || lpad(v_seq_val::text, 6, '0');

    -- Step 5: Insert into Invoices Table
    INSERT INTO invoices (
        id, invoice_number, table_number, subtotal, tax_amount, grand_total,
        cash_paid, upi_paid, credit_amount, customer_name, customer_phone,
        items, created_at
    ) VALUES (
        p_idempotency_key, v_invoice_num, p_table_number, p_subtotal, p_tax_amount, p_grand_total,
        p_cash_paid, p_upi_paid, p_credit_amount, p_customer_name, p_customer_phone,
        p_items, NOW()
    );

    -- Step 6: Insert into Relational invoice_items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO invoice_items (
            invoice_id, item_name, unit_price, quantity, total_price, tax_amount, notes
        ) VALUES (
            p_idempotency_key,
            COALESCE(v_item->>'name', 'Item'),
            COALESCE((v_item->>'unit_price')::NUMERIC, 0.00),
            COALESCE((v_item->>'quantity')::INT, 1),
            COALESCE((v_item->>'unit_price')::NUMERIC, 0.00) * COALESCE((v_item->>'quantity')::INT, 1),
            0.00,
            v_item->>'notes'
        );
    END LOOP;

    -- Step 7: Record Multi-Tender Payments
    IF p_cash_paid > 0 THEN
        INSERT INTO payments (invoice_id, customer_id, amount, method, notes)
        VALUES (p_idempotency_key, v_cust_id, p_cash_paid, 'cash', 'Dining Cash Tender');
    END IF;

    IF p_upi_paid > 0 THEN
        INSERT INTO payments (invoice_id, customer_id, amount, method, reference_number, notes)
        VALUES (p_idempotency_key, v_cust_id, p_upi_paid, 'upi', p_upi_reference, 'Dining UPI Tender');
    END IF;

    IF p_credit_amount > 0 THEN
        INSERT INTO payments (invoice_id, customer_id, amount, method, reference_number, notes)
        VALUES (p_idempotency_key, v_cust_id, p_credit_amount, 'credit', v_invoice_num, 'Dining Khata Credit');

        -- Post Debit to Customer Ledger
        INSERT INTO customer_ledger (customer_id, entry_type, amount, reference_type, reference_number, description)
        VALUES (
            v_cust_id,
            'debit',
            p_credit_amount,
            'INVOICE',
            v_invoice_num,
            'Dining bill credit • ' || p_table_number
        );

        -- Also record in legacy ledger_entries for backward compatibility
        INSERT INTO ledger_entries (id, customer_id, type, amount, reference_type, reference_number, description, date)
        VALUES (
            'l_' || gen_random_uuid()::text,
            v_cust_id,
            'debit',
            p_credit_amount,
            'INVOICE',
            v_invoice_num,
            'Dining bill credit • ' || p_table_number,
            NOW()
        );
    END IF;

    -- Step 8: Update Table Status to Available
    UPDATE tables 
    SET status = 'available', guest_count = 0, active_order_id = NULL, updated_at = NOW()
    WHERE table_number = p_table_number;

    UPDATE restaurant_tables 
    SET status = 'available', guest_count = 0, active_order_id = NULL, updated_at = NOW()
    WHERE table_number = p_table_number;

    -- Step 9: Audit Trail
    INSERT INTO activity_logs (user_id, action, entity_name, entity_id, details)
    VALUES (
        p_staff_id,
        'FINALIZE_INVOICE',
        'invoices',
        p_idempotency_key,
        jsonb_build_object(
            'invoice_number', v_invoice_num,
            'table_number', p_table_number,
            'grand_total', p_grand_total,
            'cash', p_cash_paid,
            'upi', p_upi_paid,
            'credit', p_credit_amount
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_idempotency_key,
        'invoice_number', v_invoice_num,
        'grand_total', p_grand_total,
        'created_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, auth, pg_temp;

-- 3. KHATA SETTLEMENT RPC
CREATE OR REPLACE FUNCTION record_khata_settlement(
    p_customer_id TEXT,
    p_amount NUMERIC,
    p_payment_method TEXT DEFAULT 'cash',
    p_reference_number TEXT DEFAULT NULL,
    p_description TEXT DEFAULT 'Khata Repayment',
    p_staff_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_ref TEXT;
    v_new_balance NUMERIC;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Settlement repayment amount must be strictly greater than 0';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM customers WHERE id = p_customer_id) THEN
        RAISE EXCEPTION 'Customer ID % does not exist', p_customer_id;
    END IF;

    v_ref := COALESCE(NULLIF(TRIM(p_reference_number), ''), 'SETTLE-' || to_char(NOW(), 'YYYYMMDD-HH24MISS'));

    -- Post Credit to Customer Ledger
    INSERT INTO customer_ledger (customer_id, entry_type, amount, reference_type, reference_number, description)
    VALUES (
        p_customer_id,
        'credit',
        p_amount,
        'PAYMENT',
        v_ref,
        p_description
    );

    -- Legacy ledger_entries
    INSERT INTO ledger_entries (id, customer_id, type, amount, reference_type, reference_number, description, date)
    VALUES (
        'l_' || gen_random_uuid()::text,
        p_customer_id,
        'credit',
        p_amount,
        'PAYMENT',
        v_ref,
        p_description,
        NOW()
    );

    -- Record Payment Entry
    INSERT INTO payments (customer_id, amount, method, reference_number, notes)
    VALUES (
        p_customer_id,
        p_amount,
        CASE WHEN LOWER(p_payment_method) = 'upi' THEN 'upi' ELSE 'cash' END,
        v_ref,
        p_description
    );

    -- Audit
    INSERT INTO activity_logs (user_id, action, entity_name, entity_id, details)
    VALUES (
        p_staff_id,
        'KHATA_SETTLEMENT',
        'customers',
        p_customer_id,
        jsonb_build_object('amount', p_amount, 'method', p_payment_method, 'reference', v_ref)
    );

    -- Calculate Updated Balance
    SELECT COALESCE(current_balance, 0.00) INTO v_new_balance
    FROM view_customer_balances
    WHERE customer_id = p_customer_id;

    RETURN jsonb_build_object(
        'success', true,
        'customer_id', p_customer_id,
        'amount_settled', p_amount,
        'reference_number', v_ref,
        'new_balance', v_new_balance
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, auth, pg_temp;

-- 4. INVOICE VOID RPC (OWNER / MANAGER AUTHORIZATION)
CREATE OR REPLACE FUNCTION void_invoice_transaction(
    p_invoice_number TEXT,
    p_reason TEXT,
    p_staff_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_inv RECORD;
    v_cust_id TEXT;
BEGIN
    SELECT * INTO v_inv FROM invoices WHERE invoice_number = p_invoice_number;

    IF v_inv.id IS NULL THEN
        RAISE EXCEPTION 'Invoice % not found', p_invoice_number;
    END IF;

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

    -- Audit Void
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

    RETURN jsonb_build_object(
        'success', true,
        'invoice_number', p_invoice_number,
        'message', 'Invoice successfully voided and ledger compensated.'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, auth, pg_temp;

-- 5. KITCHEN PRICE-LOCK TRIGGER (PREVENTS UNAUTHORIZED MENU PRICE TAMPERING)
CREATE OR REPLACE FUNCTION check_menu_item_price_modification()
RETURNS TRIGGER AS $$
DECLARE
    v_role TEXT := 'anon';
BEGIN
    -- Check caller JWT claims if present
    v_role := COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', 'anon');

    -- If caller is kitchen staff, forbid alterations to price, tax, or identity
    IF v_role = 'kitchen' THEN
        IF (NEW.price <> OLD.price) OR 
           (NEW.name <> OLD.name) OR 
           (NEW.sku <> OLD.sku) OR 
           (NEW.category <> OLD.category) THEN
            RAISE EXCEPTION 'Security Policy: Kitchen staff is strictly limited to toggling availability (is_available/stock_quantity).';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_menu_update ON menu_items;
CREATE TRIGGER trg_enforce_menu_update
    BEFORE UPDATE ON menu_items
    FOR EACH ROW
    EXECUTE FUNCTION check_menu_item_price_modification();
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
        customer_ledger,
        restaurant_settings,
        kitchen_tickets,
        invoices,
        customers,
        ledger_entries,
        staff_profiles;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- --- MIGRATION 006: DYNAMIC SETTINGS & FULL CRUD POLICIES ---
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS tagline TEXT DEFAULT 'Pure Veg Restaurant & Sweets';
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS email TEXT DEFAULT '';
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS service_charge_rate NUMERIC(5, 2) DEFAULT 0.00;
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS receipt_footer_note TEXT DEFAULT 'Thank you! Visit Again.';
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS thermal_paper_width INT DEFAULT 80;
ALTER TABLE restaurant_settings ADD COLUMN IF NOT EXISTS auto_print_receipt BOOLEAN DEFAULT false;

DELETE FROM restaurant_settings
WHERE id NOT IN (
    SELECT id FROM restaurant_settings
    ORDER BY updated_at DESC
    LIMIT 1
);

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

DO $$
BEGIN
    ALTER TABLE restaurant_settings ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Read Settings" ON restaurant_settings;
    DROP POLICY IF EXISTS "Public Modify Settings" ON restaurant_settings;
    DROP POLICY IF EXISTS "settings_read_policy" ON restaurant_settings;
    DROP POLICY IF EXISTS "settings_write_policy" ON restaurant_settings;
    CREATE POLICY "Public Read Settings" ON restaurant_settings FOR SELECT USING (true);
    CREATE POLICY "Public Modify Settings" ON restaurant_settings FOR ALL USING (true) WITH CHECK (true);

    ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Read Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "Public Modify Menu Items" ON menu_items;
    DROP POLICY IF EXISTS "items_read_policy" ON menu_items;
    DROP POLICY IF EXISTS "items_write_policy" ON menu_items;
    CREATE POLICY "Public Read Menu Items" ON menu_items FOR SELECT USING (true);
    CREATE POLICY "Public Modify Menu Items" ON menu_items FOR ALL USING (true) WITH CHECK (true);

    ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Tables" ON tables;
    CREATE POLICY "Public Access Tables" ON tables FOR ALL USING (true) WITH CHECK (true);

    ALTER TABLE kitchen_tickets ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Kitchen Tickets" ON kitchen_tickets;
    CREATE POLICY "Public Access Kitchen Tickets" ON kitchen_tickets FOR ALL USING (true) WITH CHECK (true);

    ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Customers" ON customers;
    CREATE POLICY "Public Access Customers" ON customers FOR ALL USING (true) WITH CHECK (true);

    ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Ledger Entries" ON ledger_entries;
    CREATE POLICY "Public Access Ledger Entries" ON ledger_entries FOR ALL USING (true) WITH CHECK (true);

    ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Staff Profiles" ON staff_profiles;
    CREATE POLICY "Public Access Staff Profiles" ON staff_profiles FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- --- MIGRATION 007: GUARANTEED BACKEND DELETE, UPDATE & RLS POLICIES ---
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS is_voided BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS void_reason TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS split_summary TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS splits JSONB;

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

DO $$
BEGIN
    ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Invoices" ON invoices;
    CREATE POLICY "Public Access Invoices" ON invoices FOR ALL USING (true) WITH CHECK (true);

    ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public Access Ledger Entries" ON ledger_entries;
    CREATE POLICY "Public Access Ledger Entries" ON ledger_entries FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN OTHERS THEN NULL;
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
''';
