import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BUCKETS = ["inventory-images", "product-images"];

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Falta el header Authorization" }, 401);
    }

    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return json({ error: "Sesion invalida o expirada" }, 401);
    }

    const userId = user.id;

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const storageErrors: string[] = [];
    for (const bucket of BUCKETS) {
      const { data: files, error: listError } = await admin.storage
        .from(bucket)
        .list(userId, { limit: 1000 });

      if (listError) {
        storageErrors.push(bucket + ": " + listError.message);
        continue;
      }

      if (files && files.length > 0) {
        const paths = files.map((f) => userId + "/" + f.name);
        const { error: removeError } = await admin.storage.from(bucket).remove(paths);
        if (removeError) storageErrors.push(bucket + ": " + removeError.message);
      }
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
    if (deleteError) {
      return json({ error: "No se pudo borrar la cuenta: " + deleteError.message }, 500);
    }

    return json({
      success: true,
      message: "Cuenta eliminada permanentemente",
      storageWarnings: storageErrors.length ? storageErrors : undefined,
    });
  } catch (e) {
    return json({ error: "Error inesperado: " + String(e) }, 500);
  }
});
