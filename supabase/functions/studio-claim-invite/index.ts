import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const APP_ORIGIN = "https://lions-rock-mail.vercel.app";
function headers(origin: string | null) {
  return {
    "Access-Control-Allow-Origin": origin === APP_ORIGIN ? origin : APP_ORIGIN,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
    "Content-Type": "application/json"
  };
}
function json(body: unknown, status: number, h: Record<string,string>) {
  return new Response(JSON.stringify(body), { status, headers: h });
}

Deno.serve(async (req) => {
  const h = headers(req.headers.get("origin"));
  if (req.method === "OPTIONS") return new Response("ok", { headers: h });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405, h);

  const authHeader = req.headers.get("authorization") || "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) return json({ error: "Unauthorized" }, 401, h);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } }
  );

  const u = await admin.auth.getUser(token);
  const user = u.data?.user;
  if (u.error || !user) return json({ error: "Unauthorized" }, 401, h);

  const callerClient = createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!,{global:{headers:{Authorization:authHeader}},auth:{persistSession:false,autoRefreshToken:false}});
  const security = await callerClient.rpc("owner_mfa_status");
  if (security.error || security.data?.allowed !== true) return json({error:"Verify your authenticator before accepting this invitation."},403,h);

  let body: Record<string, unknown>;
  try { body = await req.json(); }
  catch { return json({ error: "Invalid request" }, 400, h); }

  const accessType = String(body.access_type || "");
  if (!["business_tools","artist_member"].includes(accessType)) {
    return json({ error: "Invalid access type" }, 400, h);
  }

  const inviteRes = await admin.from("studio_invites")
    .select("*")
    .eq("user_id", user.id)
    .eq("access_type", accessType)
    .eq("status", "pending")
    .order("invited_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (inviteRes.error || !inviteRes.data) return json({ error: "No pending invitation was found." }, 404, h);

  const invite = inviteRes.data;
  const now = new Date();
  if (new Date(invite.expires_at) <= now) {
    await admin.from("studio_invites").update({ status: "revoked", updated_at: now.toISOString() }).eq("id", invite.id);
    return json({ error: "This invitation has expired. Ask Lions Rock for a new link." }, 410, h);
  }

  const membershipRes = await admin.from("app_memberships")
    .select("*")
    .eq("user_id", user.id)
    .maybeSingle();

  if (membershipRes.error) return json({ error: membershipRes.error.message }, 400, h);
  const m = membershipRes.data;

  if (m?.access_status === "suspended") {
    return json({ error: "This account is suspended. Contact Lions Rock." }, 403, h);
  }

  const businessEnabled = m?.role === "owner" || m?.business_tools_enabled === true || accessType === "business_tools";
  const artistEnabled = m?.role === "owner" || m?.artist_member_enabled === true || accessType === "artist_member";
  const plan = m?.role === "owner" ? "owner" :
    (businessEnabled && artistEnabled ? "business_and_artist" : (businessEnabled ? "business_tools" : "artist_member"));
  const paymentStatus = ["paid","comped"].includes(m?.payment_status) ? m.payment_status : invite.payment_status;

  const upsert = await admin.from("app_memberships").upsert({
    user_id: user.id,
    email: user.email || invite.email,
    business_name: invite.business_name || m?.business_name || null,
    role: m?.role === "owner" ? "owner" : "member",
    access_status: "active",
    payment_status: paymentStatus,
    plan,
    business_tools_enabled: businessEnabled,
    artist_member_enabled: artistEnabled,
    invited_at: m?.invited_at || invite.invited_at,
    invite_claimed_at: now.toISOString(),
    activated_at: m?.activated_at || now.toISOString(),
    updated_at: now.toISOString()
  }, { onConflict: "user_id" });

  if (upsert.error) return json({ error: upsert.error.message }, 500, h);

  const claimed = await admin.from("studio_invites").update({
    status: "claimed",
    claimed_at: now.toISOString(),
    updated_at: now.toISOString()
  }).eq("id", invite.id);

  if (claimed.error) return json({ error: claimed.error.message }, 500, h);

  return json({ ok: true, access_type: accessType, plan }, 200, h);
});