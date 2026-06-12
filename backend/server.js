// Feynman "curious student" backend proxy — Ollama edition.
//
// Why this exists: the model must never ship inside the Flutter binary. The
// client calls THIS server, which holds the integration point and proxies to a
// local Ollama server running qwen2.5:3b.
//
// Contract (see README.md for the full spec):
//   POST /v1/student/turn
//   body: { concept: string, explanation: string, history: Turn[] }
//   200 : { reaction, question, clarity (0-100 int), jargon: string[] }
//
// Ollama is asked for JSON output, and we still validate/clamp defensively
// before returning.

import "dotenv/config";
import express from "express";
import cors from "cors";

const PORT = process.env.PORT || 8787;
const OLLAMA_BASE_URL = (process.env.OLLAMA_BASE_URL || "http://localhost:11434").replace(/\/$/, "");
const MODEL = process.env.OLLAMA_MODEL || "qwen2.5:3b";

// The persona, given as a system instruction.
const SYSTEM_PROMPT = `You are a curious beginner learning alongside the user.

Respond like a real person in a conversation: give a short, natural reaction to what they just said, then ask one genuine follow-up question that helps keep the discussion moving. Do not sound like a grader or a checklist. Be warm, slightly informal, and easy to talk to.

If the explanation is mostly understandable, respond positively even if some details are fuzzy. Do not force criticism or nitpick wording. Prefer curiosity over precision.

Clarity should reflect how understandable the explanation feels overall, from 0 (very hard to follow) to 100 (very easy to follow), not whether every detail is technically perfect.

Identify "jargon" only when a technical term is clearly used without explanation and would likely confuse a beginner. If a term is partly explained or obvious from context, it is okay to leave it out. Return a short list of only the most useful jargon terms.

Stay in character as the learner. Do not mention that you are an AI.`;

const app = express();
app.use(cors());
app.use(express.json({ limit: "256kb" }));

function clampClarity(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return 50;
  return Math.max(0, Math.min(100, Math.round(n)));
}

function buildMessages(concept, history, explanation) {
  const messages = [{ role: "system", content: SYSTEM_PROMPT }];
  const safeHistory = Array.isArray(history) ? history : [];

  for (const turn of safeHistory) {
    if (!turn || typeof turn.text !== "string" || !turn.text.trim()) continue;
    messages.push({
      role: turn.role === "student" ? "assistant" : "user",
      content: turn.text,
    });
  }

  const lead =
    messages.length === 1
      ? `I'm going to teach you about "${concept}". Here's my explanation:\n\n`
      : `I'm teaching you about "${concept}".\n\n`;

  messages.push({
    role: "user",
    content: `${lead}${explanation}`,
  });

  return messages;
}

function stripCodeFences(text) {
  const trimmed = text.trim();
  if (!trimmed.startsWith("```")) return trimmed;

  const lines = trimmed.split(/\r?\n/);
  if (lines.length <= 2) return trimmed;

  return lines
    .slice(1, -1)
    .join("\n")
    .replace(/^json\s*/i, "")
    .trim();
}

app.get("/health", (_req, res) => res.json({ ok: true, provider: "ollama", model: MODEL }));

app.post("/v1/student/turn", async (req, res) => {
  const { concept, explanation, history } = req.body ?? {};

  if (typeof concept !== "string" || typeof explanation !== "string") {
    return res.status(400).json({
      error: "Body must include string `concept` and string `explanation`.",
    });
  }
  if (!explanation.trim()) {
    return res.status(400).json({ error: "`explanation` must not be empty." });
  }

  try {
    const response = await fetch(`${OLLAMA_BASE_URL}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        messages: buildMessages(concept, history, explanation),
        stream: false,
        format: "json",
        options: {
          temperature: 0.8,
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => "");
      console.error("[student/turn] ollama error:", response.status, errorText.slice(0, 500));
      return res.status(502).json({
        error: `Ollama returned HTTP ${response.status}.`,
      });
    }

    const payload = await response.json();
    const text = payload?.message?.content;
    if (typeof text !== "string" || !text.trim()) {
      return res.status(502).json({ error: "Empty model response." });
    }

    let parsed;
    try {
      parsed = JSON.parse(stripCodeFences(text));
    } catch {
      return res.status(502).json({ error: "Model returned non-JSON." });
    }

    // Defensive normalisation — never trust the shape blindly.
    const out = {
      reaction: typeof parsed.reaction === "string" ? parsed.reaction : "",
      question:
        typeof parsed.question === "string" && parsed.question.trim()
          ? parsed.question
          : "Can you explain that part a little more simply?",
      clarity: clampClarity(parsed.clarity),
      jargon: Array.isArray(parsed.jargon)
        ? parsed.jargon.filter((t) => typeof t === "string" && t.trim()).slice(0, 12)
        : [],
    };

    return res.json(out);
  } catch (err) {
    const msg = err?.message || String(err);
    console.error("[student/turn] error:", msg);
    return res.status(502).json({ error: "Upstream model error." });
  }
});

app.listen(PORT, () => {
  console.log(`Feynman student proxy (Ollama) listening on http://localhost:${PORT}`);
  console.log(`Model: ${MODEL}`);
  console.log(`Ollama: ${OLLAMA_BASE_URL}`);
});
