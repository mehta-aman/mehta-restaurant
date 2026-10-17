-- ==============================================================================
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
