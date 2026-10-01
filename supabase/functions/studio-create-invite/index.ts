import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const APP_ORIGIN = "https://lions-rock-mail.vercel.app";
const ACCESS_TYPES = new Set(["business_tools", "artist_member"]);

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

  const userRes = await admin.auth.getUser(token);
  const caller = userRes.data?.user;
  if (userRes.error || !caller) return json({ error: "Unauthorized" }, 401, h);

  const ownerRes = await admin.from("app_memberships")
    .select("role,access_status")
    .eq("user_id", caller.id)
    .maybeSingle();

  if (ownerRes.error || ownerRes.data?.role !== "owner" || ownerRes.data?.access_status !== "active") {
    return json({ error: "Owner access required" }, 403, h);
  }

  // Caller-scoped RPC evaluates the signed JWT assurance level; service role must not bypass it.
  const callerClient = createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!,{global:{headers:{Authorization:authHeader}},auth:{persistSession:false,autoRefreshToken:false}});
  const security = await callerClient.rpc("owner_mfa_status");
  if (security.error || security.data?.allowed !== true) return json({error:"Verify your authenticator before creating invitations."},403,h);

  let body: Record<string, unknown>;
  try { body = await req.json(); }
  catch { return json({ error: "Invalid request" }, 400, h); }

  const email = String(body.email || "").trim().toLowerCase();
  const fullName = String(body.full_name || "").trim();
  const businessName = String(body.business_name || "").trim();
  const accessType = String(body.access_type || "");
  const paymentStatus = String(body.payment_status || "");

  if (!email || !email.includes("@")) return json({ error: "A valid email is required." }, 400, h);
  if (!ACCESS_TYPES.has(accessType)) return json({ error: "Choose Business Tools or Artist Member." }, 400, h);
  if (!["paid","comped"].includes(paymentStatus)) return json({ error: "Mark the invite paid or comped first." }, 400, h);

  let target: any = null;
  for (let page = 1; page <= 10 && !target; page++) {
    const listed = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (listed.error) return json({ error: listed.error.message }, 400, h);
    target = listed.data.users.find((u) => String(u.email || "").toLowerCase() === email) || null;
    if (listed.data.users.length < 1000) break;
  }

  const existingUser = !!target;
  const redirectTo = APP_ORIGIN + "/studio.html?invite=1&access=" +
    encodeURIComponent(accessType) + "&existing=" + (existingUser ? "1" : "0");

  let linkRes: any;
  if (existingUser) {
    linkRes = await admin.auth.admin.generateLink({
      type: "magiclink",
      email,
      options: { redirectTo }
    });
  } else {
    linkRes = await admin.auth.admin.generateLink({
      type: "invite",
      email,
      options: {
        redirectTo,
        data: { full_name: fullName, business_name: businessName, invite_type: accessType }
      }
    });
    target = linkRes.data?.user || null;
  }

  if (linkRes.error || !target) {
    return json({ error: linkRes.error?.message || "Could not create invite link." }, 400, h);
  }

  const membershipRes = await admin.from("app_memberships")
    .select("*")
    .eq("user_id", target.id)
    .maybeSingle();

  if (membershipRes.error) return json({ error: membershipRes.error.message }, 400, h);

  const now = new Date();
  const expires = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  const existingMembership = membershipRes.data;

  if (!existingMembership) {
    const m = await admin.from("app_memberships").insert({
      user_id: target.id,
      email,
      business_name: businessName || null,
      role: "member",
      access_status: "pending",
      payment_status: paymentStatus,
      plan: "pending",
      business_tools_enabled: false,
      artist_member_enabled: false,
      invited_at: now.toISOString(),
      updated_at: now.toISOString()
    });
    if (m.error) return json({ error: m.error.message }, 500, h);
  }

  await admin.from("studio_invites")
    .update({ status: "revoked", updated_at: now.toISOString() })
    .eq("user_id", target.id)
    .eq("access_type", accessType)
    .eq("status", "pending");

  const inv = await admin.from("studio_invites").insert({
    user_id: target.id,
    email,
    full_name: fullName || null,
    business_name: businessName || existingMembership?.business_name || null,
    access_type: accessType,
    payment_status: paymentStatus,
    status: "pending",
    invited_by: caller.id,
    invited_at: now.toISOString(),
    expires_at: expires.toISOString(),
    updated_at: now.toISOString()
  }).select("id").single();

  if (inv.error) return json({ error: inv.error.message }, 500, h);

  const actionLink = linkRes.data?.properties?.action_link;
  if (!actionLink) return json({ error: "Invite was created, but no shareable link was returned." }, 500, h);

  return json({
    ok: true,
    invite_id: inv.data.id,
    email,
    access_type: accessType,
    existing_user: existingUser,
    expires_at: expires.toISOString(),
    invite_link: actionLink
  }, 200, h);
});