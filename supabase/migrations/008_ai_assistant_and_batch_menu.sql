-- ==============================================================================
-- MEHTA RESTAURANT MANAGEMENT SYSTEM - MIGRATION 008
-- Secure AI Operations Assistant Infrastructure, Batch Menu Import & Audit Trail
-- Target Database: mehta-restaurant (PostgreSQL / Supabase)
-- ==============================================================================

-- 1. AI AUDIT LOGS TABLE
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

-- 2. AI ACTION CONFIRMATIONS TABLE (SERVER-VERIFIED TWO-STEP FLOW)
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

-- 3. ATOMIC BATCH MENU IMPORT RPC (VALIDATES, CHECKS DUPLICATES, ATOMIC TRANSACTION)
CREATE OR REPLACE FUNCTION import_menu_items_batch(
    p_items JSONB,
    p_mode TEXT DEFAULT 'upsert', -- 'create_only' or 'upsert'
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

        -- Validate Name
        IF v_name = '' THEN
            v_errors := v_errors || jsonb_build_object('row', v_row_idx, 'error', 'Dish name is required');
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;

        -- Validate Price
        IF v_price IS NULL OR v_price < 0 THEN
            v_errors := v_errors || jsonb_build_object('row', v_row_idx, 'item', v_name, 'error', 'Valid non-negative price is required');
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;

        -- Auto-resolve category_id in menu_categories
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

        -- Check existing item by name (case-insensitive)
        SELECT id INTO v_existing_id FROM menu_items WHERE LOWER(TRIM(name)) = LOWER(v_name) LIMIT 1;

        IF v_existing_id IS NOT NULL THEN
            IF p_mode = 'create_only' THEN
                v_skipped := v_skipped + 1;
                v_errors := v_errors || jsonb_build_object('row', v_row_idx, 'item', v_name, 'status', 'skipped_duplicate');
                CONTINUE;
            ELSE
                -- Update existing price, category, and metadata
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
            -- Generate new unique item ID
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

    -- Audit log record
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
