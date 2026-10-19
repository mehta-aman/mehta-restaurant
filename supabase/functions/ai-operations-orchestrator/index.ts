// Follow Deno and Supabase Edge Functions conventions
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RequestPayload {
  message?: string;
  staff_id: string;
  pin?: string;
  confirmation_token?: string;
  conversation_history?: Array<{ role: string; content: string }>;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const aiApiKey = Deno.env.get("AI_PROVIDER_API_KEY") || Deno.env.get("GEMINI_API_KEY") || "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const payload: RequestPayload = await req.json();
    const { staff_id, pin, confirmation_token, message, conversation_history } = payload;

    if (!staff_id) {
      return new Response(
        JSON.stringify({ success: false, error: "Authentication Error: staff_id is required." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Verify staff profile and role directly from database
    const { data: staff, error: staffError } = await supabase
      .from("staff_profiles")
      .select("id, staff_code, full_name, role, is_active")
      .eq("id", staff_id)
      .maybeSingle();

    if (staffError || !staff || !staff.is_active) {
      return new Response(
        JSON.stringify({ success: false, error: "Access Denied: Inactive or unrecognized staff profile." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Handle Action Confirmation Execution if a token was supplied
    if (confirmation_token) {
      const { data: tokenRecord, error: tokenErr } = await supabase
        .from("ai_action_confirmations")
        .select("*")
        .eq("token", confirmation_token)
        .eq("is_consumed", false)
        .maybeSingle();

      if (tokenErr || !tokenRecord) {
        return new Response(
          JSON.stringify({ success: false, error: "Invalid or already consumed confirmation token." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (new Date(tokenRecord.expires_at) < new Date()) {
        return new Response(
          JSON.stringify({ success: false, error: "Confirmation token has expired. Please re-issue the command." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Mark token consumed
      await supabase
        .from("ai_action_confirmations")
        .update({ is_consumed: true, consumed_at: new Date().toISOString() })
        .eq("token", confirmation_token);

      // Execute based on operation
      let executionResult: any = { success: true };

      if (tokenRecord.operation_name === "import_menu_items_batch") {
        const { data: batchRes, error: batchErr } = await supabase.rpc("import_menu_items_batch", {
          p_items: tokenRecord.parameters.items,
          p_mode: tokenRecord.parameters.mode || "upsert",
          p_staff_id: staff.id,
        });
        if (batchErr) throw batchErr;
        executionResult = batchRes;
      }

      // Record audit log
      await supabase.from("ai_audit_logs").insert({
        staff_id: staff.id,
        staff_name: staff.full_name,
        staff_role: staff.role,
        tool_name: tokenRecord.operation_name,
        arguments: tokenRecord.parameters,
        success: true,
        user_prompt: `Confirmed token: ${confirmation_token}`,
      });

      return new Response(
        JSON.stringify({
          success: true,
          action_executed: true,
          operation: tokenRecord.operation_name,
          result: executionResult,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Process natural language query
    return new Response(
      JSON.stringify({
        success: true,
        authenticated_staff: {
          id: staff.id,
          name: staff.full_name,
          role: staff.role,
        },
        message: `Processed for ${staff.full_name} (${staff.role}).`,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal Server Error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
