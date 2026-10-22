// OneUp Companion — Supabase Edge Function.
// Builds the system prompt from spec.json server-side (client cannot alter it), calls an
// OpenAI-compatible chat API, and returns JSON validated against spec.response_format.output_schema.
// Secrets (never shipped in the app): AI_API_KEY, AI_BASE_URL (e.g. https://api.example.com/v1), AI_MODEL.
import spec from "./spec.json" with { type: "json" };

type Risk = "none" | "elevated" | "crisis";
interface Reply {
  reply: string;
  risk_level: Risk;
  dimension_focus: string | null;
  suggested_action: { type: "skill" | "content" | "consultant" | "none"; id: string | null };
  flag_for_review: boolean;
}

const DIMS = ["emotional", "physical", "occupational", "social", "spiritual", "intellectual", "environmental", "financial"];
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const band = (s: number) => (s <= 40 ? "Needs Attention" : s <= 70 ? "Developing" : "Thriving");

// Server-side safety net (the app has a fuller multilingual layer too).
const CRISIS = [/suicid/, /kill (myself|someone)/, /end (my|it all)/, /(don'?t|do not) want to (live|be alive)/, /want to die/,
  /self.?harm/, /hurt (myself|someone)/, /hearing voices/, /chest pain/, /can'?t breathe/, /khudkushi|aatmhatya|jeena nahi/,
  /thatkolai|saaga poren|vazha pidikkala/];
const isCrisis = (t: string) => CRISIS.some((r) => r.test(t.toLowerCase()));

const CRISIS_REPLY: Reply = {
  reply: "I'm really sorry you're feeling this way, and I'm glad you told me. You deserve support right now. Please reach out to someone you trust, or contact emergency or crisis services now. I'm showing you helpline numbers, and I can help you contact someone.",
  risk_level: "crisis", dimension_focus: null, suggested_action: { type: "none", id: null }, flag_for_review: true,
};

function systemPrompt(scores: Record<string, number> | null, escalate: string[], language: string): string {
  const s = spec as any;
  const scoreLines = scores
    ? DIMS.map((d) => (d in scores ? `- ${d}: ${scores[d]} (${band(scores[d])})` : `- ${d}: not assessed`)).join("\n")
    : "The user has NOT consented to sharing scores. Do not reference specific scores; ask if needed.";
  return [
    `You are ${s.agent.display_name} by ${s.agent.owner}. ${s.role.summary}`,
    `You are: ${s.role.is.join(", ")}. You are NOT: ${s.role.is_not.join(", ")}.`,
    `Identity: ${s.role.identity_rule}`,
    `First-session disclaimer (use if relevant): ${s.disclaimers.first_session}`,
    `ALLOWED:\n- ${s.scope.allowed.join("\n- ")}`,
    `NOT ALLOWED:\n- ${s.scope.not_allowed.join("\n- ")}`,
    `STYLE: ${s.conversation_framework.style}\nTurn structure:\n${s.conversation_framework.turn_structure.join("\n")}`,
    `Avoid: ${s.conversation_framework.avoid.join("; ")}. ${s.conversation_framework.technique_note}`,
    `SAFETY. Crisis triggers: ${s.safety.crisis_triggers.join("; ")}.\nCrisis protocol:\n- ${s.safety.crisis_protocol.join("\n- ")}`,
    `${s.safety.low_score_rule} ${s.safety.no_secrecy_promises}`,
    `ANTI-HALLUCINATION:\n- ${s.anti_hallucination.rules.join("\n- ")}`,
    `Missing data: ${s.inputs.missing_data_rule}`,
    `RECOMMENDATIONS: ${s.recommendation_rules.trigger} Priority: ${s.recommendation_rules.priority_order.join(" > ")}. ` +
      `${s.recommendation_rules.medicines_supplements_rule} ${s.recommendation_rules.disclosure} ${s.recommendation_rules.limit}`,
    `Consultant escalation only when: ${s.recommendation_rules.consultant_escalation_when.join("; ")}. ` +
      `Dimensions currently meeting the "low across 2+ assessments" rule: ${escalate.length ? escalate.join(", ") : "none"}.`,
    `PLAYBOOK (skill ids for suggested_action.id): ${JSON.stringify(s.dimension_playbook)}`,
    `For consultant actions, suggested_action.id must be one of: psychologist, therapist, nutritionist, wellnessCoach. Never invent names.`,
    `Score bands: 0-40 Needs Attention, 41-70 Developing, 71-100 Thriving. Scores are wellness indicators, never clinical findings.`,
    `USER SCORES:\n${scoreLines}`,
    `Reply language: ${language}. Max ${s.response_format.max_words} words. Tone: ${s.response_format.tone}. ${s.response_format.structure}.`,
    `OUTPUT: respond with ONLY a JSON object matching exactly: ${JSON.stringify(s.response_format.output_schema)}. ` +
      `dimension_focus is one of ${DIMS.join(", ")} or null.`,
  ].join("\n\n");
}

function validate(x: any): Reply {
  if (!x || typeof x.reply !== "string" || !x.reply.trim()) throw new Error("reply");
  if (!["none", "elevated", "crisis"].includes(x.risk_level)) throw new Error("risk_level");
  if (x.dimension_focus !== null && !DIMS.includes(x.dimension_focus)) throw new Error("dimension_focus");
  const sa = x.suggested_action;
  if (!sa || !["skill", "content", "consultant", "none"].includes(sa.type)) throw new Error("suggested_action");
  if (sa.id !== null && typeof sa.id !== "string") throw new Error("suggested_action.id");
  if (typeof x.flag_for_review !== "boolean") throw new Error("flag_for_review");
  const words = x.reply.replace(/\[VERIFY[^\]]*\]/g, "").trim().split(/\s+/);
  const crisis = x.risk_level === "crisis";
  return {
    reply: words.slice(0, (spec as any).response_format.max_words).join(" "),
    risk_level: x.risk_level,
    dimension_focus: x.dimension_focus,
    suggested_action: crisis ? { type: "none", id: null } : { type: sa.type, id: sa.id },
    flag_for_review: x.flag_for_review || crisis,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (b: unknown, status = 200) =>
    new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });
  try {
    const { message, history = [], scores = null, escalate = [], language = "en" } = await req.json();
    if (typeof message !== "string" || !message.trim() || message.length > 2000) return json({ error: "bad message" }, 400);
    if (isCrisis(message)) return json(CRISIS_REPLY);

    const key = Deno.env.get("AI_API_KEY"), base = Deno.env.get("AI_BASE_URL"), model = Deno.env.get("AI_MODEL");
    if (!key || !base || !model) return json({ error: "AI not configured" }, 503);

    const msgs = [
      { role: "system", content: systemPrompt(scores, escalate, language) },
      ...(Array.isArray(history) ? history.slice(-12) : [])
        .filter((m: any) => (m.role === "user" || m.role === "assistant") && typeof m.content === "string")
        .map((m: any) => ({ role: m.role, content: String(m.content).slice(0, 2000) })),
      { role: "user", content: message },
    ];
    const r = await fetch(`${base.replace(/\/$/, "")}/chat/completions`, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model, messages: msgs, temperature: 0.4, max_tokens: 400, response_format: { type: "json_object" } }),
    });
    if (!r.ok) return json({ error: `upstream ${r.status}` }, 502);
    const data = await r.json();
    const content = data?.choices?.[0]?.message?.content ?? "";
    let out: Reply;
    try {
      out = validate(JSON.parse(content));
    } catch {
      return json({ error: "invalid model output" }, 502); // app falls back to its offline responder
    }
    if (isCrisis(out.reply)) out = CRISIS_REPLY;
    return json(out);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
