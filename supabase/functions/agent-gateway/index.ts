import { createClient } from "npm:@supabase/supabase-js@2.57.4";

type JobKind = "assistant_request" | "daily_plan" | "draft_message" | "draft_quote";

const allowedKinds = new Set<JobKind>([
  "assistant_request",
  "daily_plan",
  "draft_message",
  "draft_quote",
]);

function corsHeaders(origin: string | null) {
  return {
    "Access-Control-Allow-Origin": origin ?? "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
  };
}

Deno.serve(async (request) => {
  const headers = corsHeaders(request.headers.get("origin"));
  if (request.method === "OPTIONS") return new Response("ok", { headers });
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers });
  }

  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Authentication required" }), { status: 401, headers });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Invalid session" }), { status: 401, headers });
  }

  let body: { kind?: JobKind; input?: Record<string, unknown> };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), { status: 400, headers });
  }

  const kind = body.kind ?? "assistant_request";
  if (!allowedKinds.has(kind)) {
    return new Response(JSON.stringify({ error: "Unsupported job kind" }), { status: 400, headers });
  }

  const input = body.input ?? {};
  const inputSize = JSON.stringify(input).length;
  if (inputSize > 20_000) {
    return new Response(JSON.stringify({ error: "Input is too large" }), { status: 413, headers });
  }

  const { data, error } = await supabase
    .from("agent_jobs")
    .insert({ owner_id: user.id, kind, input })
    .select("id, kind, status, created_at")
    .single();

  if (error) {
    return new Response(JSON.stringify({ error: "Could not enqueue agent job" }), { status: 500, headers });
  }

  return new Response(JSON.stringify({ job: data }), { status: 202, headers });
});
