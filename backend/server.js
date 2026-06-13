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

app.listen(PORT, () => {
  console.log(`Feynman student proxy (Gemini) listening on http://localhost:${PORT}`);
  console.log(`Model: ${MODEL}`);
});
