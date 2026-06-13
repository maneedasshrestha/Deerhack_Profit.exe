// Feynman "curious student" backend proxy — Google Gemini edition.
//
// Uses the new unified @google/genai SDK (the JS twin of the Python
// `from google import genai` SDK). It authenticates via header, so it supports
// both the classic `AIza…` keys and the newer `AQ.…` key format.
//
// Why this exists: the LLM API key must never ship inside the Flutter binary
// (it is trivially extractable from a built app). The client calls THIS server,
// which holds the key and proxies to Google's Gemini API.
//
// Contract (see README.md for the full spec):
//   POST /v1/student/turn
//   body: { concept: string, explanation: string, history: Turn[] }
//   200 : { reaction, question, clarity (0-100 int), jargon: string[] }
//
// Gemini is asked for STRICT JSON via responseSchema, and we still
// validate/clamp defensively before returning.

import "dotenv/config";
import express from "express";
import cors from "cors";
import { GoogleGenAI, Type } from "@google/genai";

const PORT = process.env.PORT || 8787;
const MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";
const API_KEY = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;

if (!API_KEY) {
  console.error(
    "[fatal] GEMINI_API_KEY is not set. Copy .env.example to .env and fill it in."
  );
  process.exit(1);
}

const ai = new GoogleGenAI({ apiKey: API_KEY });

// The persona, given as a system instruction.
const SYSTEM_PROMPT = `You are a curious, friendly 12-year-old student. The user is teaching you a concept out loud.

React briefly and naturally to what they just said (one short, human sentence — the way a real kid would: "Oh okay...", "Wait, so...", "Huh, I think I get it"). Then ask EXACTLY ONE follow-up question about the part of their explanation that was vaguest, most jargon-heavy, or hand-waved. Keep the question short, concrete, and genuinely curious — never sarcastic, never a quiz, never multiple questions stacked together.

Also assess how clearly they explained, from 0 (total word-salad) to 100 (a 12-year-old would now truly understand it).

Identify any "jargon": specific technical terms the user used WITHOUT first explaining them in plain language. Copy each term verbatim as it appeared in their explanation (so it can be highlighted in their transcript). If they explained a term in simple words, it is NOT jargon. Return an empty list if they kept it plain.

Stay in character as the student. Do not break character or mention that you are an AI.`;

// Structured-output schema. Guarantees the response is valid JSON in this shape.
const RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    reaction: { type: Type.STRING },
    question: { type: Type.STRING },
    clarity: { type: Type.INTEGER },
    jargon: { type: Type.ARRAY, items: { type: Type.STRING } },
  },
  required: ["reaction", "question", "clarity", "jargon"],
  propertyOrdering: ["reaction", "question", "clarity", "jargon"],
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

/**
 * Build the Gemini `contents` array from prior turns + the latest explanation.
 * history entries: { role: "user" | "student", text: string }
 *   user    -> the learner's explanation  -> Gemini role "user"
 *   student -> the student's question      -> Gemini role "model"
 */
function buildContents(concept, history, explanation) {
  const contents = [];
  const safeHistory = Array.isArray(history) ? history : [];

  for (const turn of safeHistory) {
    if (!turn || typeof turn.text !== "string" || !turn.text.trim()) continue;
    contents.push({
      role: turn.role === "student" ? "model" : "user",
      parts: [{ text: turn.text }],
    });
  }

  const lead =
    contents.length === 0
      ? `I'm going to teach you about "${concept}". Here's my explanation:\n\n`
      : "";
  contents.push({ role: "user", parts: [{ text: `${lead}${explanation}` }] });

  // Gemini requires the first content to have role "user".
  if (contents[0].role !== "user") {
    contents.unshift({
      role: "user",
      parts: [{ text: `I'm teaching you about "${concept}".` }],
    });
  }
  return contents;
}

app.get("/health", (_req, res) => res.json({ ok: true, model: MODEL }));

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
    const response = await ai.models.generateContent({
      model: MODEL,
      contents: buildContents(concept, history, explanation),
      config: {
        systemInstruction: SYSTEM_PROMPT,
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA,
        temperature: 0.8,
      },
    });

    const text = response.text;
    if (!text) {
      return res.status(502).json({ error: "Empty model response." });
    }

    let parsed;
    try {
      parsed = JSON.parse(text);
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
    // Surface quota problems distinctly so the cause is obvious in logs.
    if (msg.includes("RESOURCE_EXHAUSTED") || msg.includes("429")) {
      return res.status(429).json({
        error:
          "Gemini quota exceeded for this project. The API key is valid but its " +
          "project has no available quota — enable billing or use a key from a " +
          "project that has free-tier quota.",
      });
    }
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
  console.log(`Feynman student proxy (Gemini) listening on http://localhost:${PORT}`);
  console.log(`Model: ${MODEL}`);
});
