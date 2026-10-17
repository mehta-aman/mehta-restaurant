-- ==============================================================================
-- MEHTA RESTAURANT MANAGEMENT SYSTEM - MIGRATION 005
-- Dynamic Bills & Invoices Management, CRUD Operations, and Safe Rejections
-- Target Database: mehta-restaurant (PostgreSQL / Supabase)
-- ==============================================================================

-- 1. ENSURE INVOICES TABLE EXISTS WITH FULL COLUMN SET
CREATE TABLE IF NOT EXISTS invoices (
    id TEXT PRIMARY KEY,
    invoice_number TEXT NOT NULL UNIQUE,
    table_number TEXT NOT NULL,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    grand_total NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
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

-- Ensure all columns are present if the table was pre-existing
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS is_voided BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS void_reason TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS splits JSONB;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS split_summary TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS grand_total NUMERIC(10, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS cash_paid NUMERIC(10, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS upi_paid NUMERIC(10, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS credit_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS customer_phone TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS items JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 2. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON invoices (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_invoice_number ON invoices (invoice_number);
CREATE INDEX IF NOT EXISTS idx_invoices_customer_phone ON invoices (customer_phone);
CREATE INDEX IF NOT EXISTS idx_invoices_is_voided ON invoices (is_voided);

-- 3. ROW LEVEL SECURITY (RLS) POLICIES FOR FULL CRUD
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Public Access Invoices" ON invoices;
    DROP POLICY IF EXISTS "Invoices Select Policy" ON invoices;
    DROP POLICY IF EXISTS "Invoices Insert Policy" ON invoices;
    DROP POLICY IF EXISTS "Invoices Update Policy" ON invoices;
    DROP POLICY IF EXISTS "Invoices Delete Policy" ON invoices;

    -- Full CRUD policy for POS terminals & staff
    CREATE POLICY "Public Access Invoices" ON invoices FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 4. ATOMIC REJECT / VOID INVOICE TRANSACTION RPC
-- Safely marks bill as voided and reverses customer Khata credit if applicable
CREATE OR REPLACE FUNCTION void_invoice_transaction(
    p_invoice_number TEXT,
    p_reason TEXT DEFAULT 'Voided by Management'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_cust_id TEXT;
    v_new_balance NUMERIC;
BEGIN
    -- 1. Fetch invoice
    SELECT * INTO v_inv FROM invoices WHERE invoice_number = p_invoice_number FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invoice not found: ' || p_invoice_number);
    END IF;

    IF v_inv.is_voided THEN
        RETURN jsonb_build_object('success', true, 'message', 'Invoice is already voided');
    END IF;

    -- 2. Mark invoice as voided
    UPDATE invoices
    SET is_voided = true,
        void_reason = p_reason
    WHERE invoice_number = p_invoice_number;

    -- 3. If credit was issued to Khata, reverse it in ledger_entries / customer_ledger
    IF v_inv.credit_amount > 0 AND v_inv.customer_phone IS NOT NULL AND TRIM(v_inv.customer_phone) <> '' THEN
        -- Locate customer
        SELECT id INTO v_cust_id FROM customers WHERE phone = v_inv.customer_phone LIMIT 1;
        
        IF v_cust_id IS NOT NULL THEN
            -- Check which ledger table is active
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customer_ledger') THEN
                INSERT INTO customer_ledger (customer_id, entry_type, amount, reference_type, reference_number, description)
                VALUES (
                    v_cust_id::UUID,
                    'credit',
                    v_inv.credit_amount,
                    'VOID_REVERSAL',
                    v_inv.invoice_number,
                    'Reversal of Voided Bill ' || v_inv.invoice_number || ': ' || p_reason
                );
            END IF;

            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ledger_entries') THEN
                INSERT INTO ledger_entries (id, customer_id, type, amount, reference_type, reference_number, description, date)
                VALUES (
                    'le_rev_' || substr(md5(random()::text), 1, 16),
                    v_cust_id,
                    'credit',
                    v_inv.credit_amount,
                    'VOID_REVERSAL',
                    v_inv.invoice_number,
                    'Reversal of Voided Bill ' || v_inv.invoice_number || ': ' || p_reason,
                    NOW()
                );
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Invoice ' || p_invoice_number || ' rejected and marked voided successfully',
        'credit_reversed', COALESCE(v_inv.credit_amount, 0)
    );
END;
$$;
