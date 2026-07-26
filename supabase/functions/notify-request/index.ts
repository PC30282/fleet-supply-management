const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type SupplyRequest = {
  section?: string;
  item?: string;
  vehicle?: string;
  quantity?: number;
  requester?: string;
  notes?: string;
  status?: string;
  created_at?: string;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function escapeHtml(value: unknown) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;",
  }[char] ?? char));
}

function requestRows(request: SupplyRequest) {
  const rows = [
    ["Section", request.section],
    ["Item", request.item],
    ["Quantity", request.quantity],
    ["Vehicle", request.vehicle || "No vehicle"],
    ["Requested by", request.requester ? `Collar ${request.requester}` : "Not supplied"],
    ["Status", request.status || "Pending"],
    ["Notes", request.notes || "None"],
  ];

  return rows.map(([label, value]) => `
    <tr>
      <th style="text-align:left;padding:8px;border-bottom:1px solid #e5e7eb;color:#374151">${escapeHtml(label)}</th>
      <td style="padding:8px;border-bottom:1px solid #e5e7eb;color:#111827">${escapeHtml(value)}</td>
    </tr>
  `).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const fromEmail = Deno.env.get("FROM_EMAIL") || "Fleet Supply Management <onboarding@resend.dev>";

  if (!resendApiKey) {
    return jsonResponse({ error: "RESEND_API_KEY is not set in Supabase Edge Function secrets" }, 500);
  }

  let payload: { email?: string; request?: SupplyRequest };
  try {
    payload = await req.json();
  } catch (_error) {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const email = String(payload.email || "").trim();
  const request = payload.request || {};

  if (!email) {
    return jsonResponse({ error: "Email recipient is required" }, 400);
  }

  if (!request.item && !request.section) {
    return jsonResponse({ error: "Request details are required" }, 400);
  }

  const subject = request.section === "Fleet Status"
    ? `Fleet status update: ${request.vehicle || request.item || "Vehicle"}`
    : `New supply request: ${request.item || "Item requested"}`;

  const html = `
    <div style="font-family:Arial,sans-serif;line-height:1.5;color:#111827">
      <h2 style="margin:0 0 12px">${escapeHtml(subject)}</h2>
      <p style="margin:0 0 16px">A new Fleet Supply Management notification has been generated.</p>
      <table style="border-collapse:collapse;width:100%;max-width:640px;border:1px solid #e5e7eb">
        ${requestRows(request)}
      </table>
      <p style="margin-top:16px;color:#4b5563">Open the Fleet Supply Management dashboard to review or update this item.</p>
    </div>
  `;

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromEmail,
      to: [email],
      subject,
      html,
    }),
  });

  const result = await response.json().catch(() => ({}));

  if (!response.ok) {
    return jsonResponse({ error: "Resend failed to send the email", details: result }, response.status);
  }

  return jsonResponse({ ok: true, result });
});
