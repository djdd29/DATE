
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const respond = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });

  if (!["GET", "POST"].includes(req.method)) {
    return respond({ error: "Method not allowed" }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization");

  if (!url || !serviceKey || !authHeader?.startsWith("Bearer ")) {
    return respond({ error: "Unauthorized" }, 401);
  }

  const token = authHeader.slice(7);

  const authClient = createClient(
    url,
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  );

  const { data: authData, error: authError } =
    await authClient.auth.getUser(token);

  if (
    authError ||
    !authData.user ||
    authData.user.app_metadata?.role !== "admin"
  ) {
    return respond({ error: "Forbidden" }, 403);
  }

  const db = createClient(url, serviceKey);

  if (req.method === "GET") {
    const { data, error } = await db
      .from("portal_state")
      .select("data, updated_at")
      .eq("id", "main")
      .single();

    if (error) return respond({ error: "Load failed" }, 500);

    return respond(data);
  }

  let body: { data?: unknown };

  try {
    body = await req.json();
  } catch {
    return respond({ error: "Invalid JSON" }, 400);
  }

  if (
    !body ||
    typeof body.data !== "object" ||
    body.data === null ||
    Array.isArray(body.data)
  ) {
    return respond({ error: "Invalid data" }, 400);
  }

  const { data, error } = await db
    .from("portal_state")
    .update({
      data: body.data,
      updated_at: new Date().toISOString(),
    })
    .eq("id", "main")
    .select("updated_at")
    .single();

  if (error) return respond({ error: "Save failed" }, 500);

  return respond({ ok: true, updated_at: data.updated_at });
});
