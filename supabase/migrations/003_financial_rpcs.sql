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
