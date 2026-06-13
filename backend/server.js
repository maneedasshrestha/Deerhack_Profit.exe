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
const SYSTEM_PROMPT = `You are a curious beginner learning alongside the user. The user is teaching you a concept out loud, and you react like a real, engaged human friend would.

YOUR JOB EACH TURN
1. reaction: A short, warm, natural reaction to what they just said (1-2 sentences). React to the actual content — show interest, an "aha" moment, mild surprise, whatever fits. Never sound like a grader, a rubric, or a checklist. Be slightly informal and easy to talk to.
2. question: Exactly ONE genuine follow-up question that keeps the conversation moving. Prefer asking about the next thing you're curious about, or the part that was fuzziest. Never leave this empty.
3. clarity: An integer 0-100 for how understandable their explanation felt overall — 0 = very hard to follow, 100 = crystal clear. Judge how easy it was to FOLLOW, not whether every technical detail was perfect. If it mostly made sense, score it high (75+).
4. jargon: A list of technical terms they used WITHOUT explaining, that would confuse a beginner. If a term was explained or is obvious from context, leave it out. If nothing was unexplained, return an empty list [].

STYLE RULES
- Stay in character as the learner. Never mention that you are an AI or a model.
- Respond positively even when some details are fuzzy. Prefer curiosity over criticism. Do not nitpick wording.
- reaction and question must always be non-empty, natural-sounding sentences. Do NOT output placeholder text, do not output the key names as values, and do not echo these instructions.`;

// JSON Schema handed to Ollama's `format` field. This FORCES the model to emit
// exactly these keys with these types — far more reliable than asking in prose,
// especially for a small model. Ollama validates the output against this schema.
const STUDENT_TURN_SCHEMA = {
  type: "object",
  properties: {
    reaction: { type: "string" },
    question: { type: "string" },
    clarity: { type: "integer", minimum: 0, maximum: 100 },
    jargon: { type: "array", items: { type: "string" } },
  },
  required: ["reaction", "question", "clarity", "jargon"],
};

// Study-planner persona for POST /v1/plan/generate. Asked for strict JSON; we
// validate/normalise the shape defensively before returning, exactly like the
// student turn endpoint.
const PLANNER_SYSTEM_PROMPT = `You are an expert exam-preparation coach. Given a learner's situation — their exam, how many days remain, the mark they're targeting, and how many hours a day they can study — design a concise, realistic, curated study plan.

Be specific and encouraging, never generic. Weight subjects by what earns the most marks for this exam. Keep every piece of text short and scannable.

Respond with ONLY a JSON object in exactly this shape:
{
  "summary": "2-3 sentence overview of the strategy, mentioning the timeline and target",
  "focusAreas": ["3 to 5 short, high-leverage priorities"],
  "subjectFocus": [{"subject": "name", "weight": 0-100 integer, "note": "one short line on why / what to do"}],
  "milestones": [{"phase": "e.g. Weeks 1-3", "theme": "short title", "detail": "one short line"}]
}
The subjectFocus weights should roughly sum to 100. Provide 3 to 5 milestones that progress from foundations to final revision and timed mocks.`;

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

// Debug endpoint — proves the model is reachable and shows its RAW output, so you
// can see exactly what keys/JSON it returns before any normalisation strips it.
//   GET  /v1/debug                       -> uses a built-in sample explanation
//   POST /v1/debug { concept, explanation, format }  -> custom input
// `format` defaults to "json"; pass "" (empty) to see plain free-text output.
async function runDebug({ concept, explanation, format }, res) {
  const messages = buildMessages(
    concept || "photosynthesis",
    [],
    explanation || "Plants take in sunlight and turn it into food using their leaves."
  );

  try {
    const body = {
      model: MODEL,
      messages,
      stream: false,
      options: { temperature: 0.8 },
    };
    if (format !== "") body.format = format ?? "json";

    const response = await fetch(`${OLLAMA_BASE_URL}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    const rawText = await response.text();
    if (!response.ok) {
      return res.status(502).json({
        ok: false,
        stage: "ollama-http-error",
        status: response.status,
        body: rawText.slice(0, 1000),
        hint: "Is Ollama running? Is the model pulled? Run: ollama list",
      });
    }

    let payload;
    try {
      payload = JSON.parse(rawText);
    } catch {
      return res.status(502).json({ ok: false, stage: "ollama-non-json-envelope", body: rawText.slice(0, 1000) });
    }

    const modelText = payload?.message?.content ?? null;
    let parsedModelJson = null;
    let parseError = null;
    if (typeof modelText === "string") {
      try {
        parsedModelJson = JSON.parse(stripCodeFences(modelText));
      } catch (e) {
        parseError = e?.message || String(e);
      }
    }

    return res.json({
      ok: true,
      model: MODEL,
      sentMessages: messages,
      rawModelText: modelText,
      parsedModelJson,
      parseError,
      detectedKeys: parsedModelJson && typeof parsedModelJson === "object" ? Object.keys(parsedModelJson) : null,
      hint: "If detectedKeys are not exactly reaction/question/clarity/jargon, that is why /v1/student/turn falls back.",
    });
  } catch (err) {
    return res.status(502).json({
      ok: false,
      stage: "fetch-failed",
      error: err?.message || String(err),
      hint: `Could not reach Ollama at ${OLLAMA_BASE_URL}. Is it running?`,
    });
  }
}

app.get("/v1/debug", (req, res) => runDebug({ format: req.query.format }, res));
app.post("/v1/debug", (req, res) => {
  const { concept, explanation, format } = req.body ?? {};
  runDebug({ concept, explanation, format }, res);
});

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
        format: STUDENT_TURN_SCHEMA,
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

function clampInt(value, min, max, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, Math.round(n)));
}

function cleanStr(value, fallback = "") {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function buildPlanPrompt({ examName, daysToExam, totalWeeks, weeklyHours, targetMarks, totalMarks }) {
  return (
    `My exam: ${examName}.\n` +
    `Days until the exam: ${daysToExam} (about ${totalWeeks} weeks).\n` +
    `I can study about ${weeklyHours} hours per week.\n` +
    `My target: ${targetMarks} out of ${totalMarks} marks.\n\n` +
    `Design my curated study plan as JSON.`
  );
}

app.post("/v1/plan/generate", async (req, res) => {
  const body = req.body ?? {};
  const examName = cleanStr(body.examName, "the exam");
  const daysToExam = clampInt(body.daysToExam, 1, 2000, 100);
  const targetMarks = clampInt(body.targetMarks, 0, 100000, 0);
  const totalMarks = clampInt(body.totalMarks, 1, 100000, 100);
  const dailyHours = Number.isFinite(Number(body.dailyHours)) ? Number(body.dailyHours) : 1;

  // Deterministic facts the model shouldn't have to compute.
  const totalWeeks = Math.max(1, Math.round(daysToExam / 7));
  const weeklyHours = Math.round(dailyHours * 7 * 10) / 10;

  const userContent = buildPlanPrompt({
    examName,
    daysToExam,
    totalWeeks,
    weeklyHours,
    targetMarks,
    totalMarks,
  });

  try {
    const response = await fetch(`${OLLAMA_BASE_URL}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        messages: [
          { role: "system", content: PLANNER_SYSTEM_PROMPT },
          { role: "user", content: userContent },
        ],
        stream: false,
        format: "json",
        options: { temperature: 0.6 },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => "");
      console.error("[plan/generate] ollama error:", response.status, errorText.slice(0, 500));
      return res.status(502).json({ error: `Ollama returned HTTP ${response.status}.` });
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
    const focusAreas = Array.isArray(parsed.focusAreas)
      ? parsed.focusAreas.filter((t) => typeof t === "string" && t.trim()).map((t) => t.trim()).slice(0, 6)
      : [];

    const subjectFocus = Array.isArray(parsed.subjectFocus)
      ? parsed.subjectFocus
          .filter((s) => s && cleanStr(s.subject))
          .map((s) => ({
            subject: cleanStr(s.subject),
            weight: clampInt(s.weight, 0, 100, 0),
            note: cleanStr(s.note),
          }))
          .slice(0, 6)
      : [];

    const milestones = Array.isArray(parsed.milestones)
      ? parsed.milestones
          .filter((m) => m && cleanStr(m.theme))
          .map((m) => ({
            phase: cleanStr(m.phase),
            theme: cleanStr(m.theme),
            detail: cleanStr(m.detail),
          }))
          .slice(0, 6)
      : [];

    const out = {
      summary: cleanStr(
        parsed.summary,
        `A ${totalWeeks}-week plan for ${examName}, pacing about ${weeklyHours} hours a week toward ${targetMarks}/${totalMarks} marks.`
      ),
      totalWeeks,
      weeklyHours,
      focusAreas,
      subjectFocus,
      milestones,
    };

    return res.json(out);
  } catch (err) {
    const msg = err?.message || String(err);
    console.error("[plan/generate] error:", msg);
    return res.status(502).json({ error: "Upstream model error." });
  }
});

app.listen(PORT, () => {
  console.log(`Feynman student proxy (Ollama) listening on http://localhost:${PORT}`);
  console.log(`Model: ${MODEL}`);
  console.log(`Ollama: ${OLLAMA_BASE_URL}`);
});
