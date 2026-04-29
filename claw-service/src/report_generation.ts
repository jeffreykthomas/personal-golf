import {
  SelfUnderstandingReportPayload,
  SelfUnderstandingReportRespondRequest,
  SelfUnderstandingReportRespondResponse,
} from "./contracts/report_events";

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const DEFAULT_MODEL = process.env.PROFILE_MODEL || "claude-sonnet-4-6";
const DEFAULT_MAX_OUTPUT_TOKENS = Number(process.env.PROFILE_MAX_OUTPUT_TOKENS || 6_000);

type AnthropicMessageResponse = {
  content?: Array<{
    type?: string;
    text?: string;
  }>;
  error?: {
    message?: string;
  };
};

export async function generateSelfUnderstandingReport(
  request: SelfUnderstandingReportRespondRequest,
): Promise<SelfUnderstandingReportRespondResponse> {
  const text = await callAnthropic(request.prompt);
  const report = parseReportPayload(text);

  return {
    requestId: request.requestId,
    report,
  };
}

async function callAnthropic(prompt: string): Promise<string> {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    throw new Error("Missing ANTHROPIC_API_KEY");
  }

  const response = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: DEFAULT_MODEL,
      max_tokens: DEFAULT_MAX_OUTPUT_TOKENS,
      temperature: 0.4,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
    }),
  });

  const rawText = await response.text();
  if (!response.ok) {
    throw new Error(`Anthropic API error: ${response.status} ${rawText.slice(0, 300)}`);
  }

  const data = JSON.parse(rawText) as AnthropicMessageResponse;
  const text = Array.isArray(data.content)
    ? data.content
        .filter((block) => block.type === "text")
        .map((block) => block.text || "")
        .join("\n")
        .trim()
    : "";

  if (!text) {
    throw new Error("Anthropic returned no text content");
  }

  return text;
}

function parseReportPayload(text: string): SelfUnderstandingReportPayload {
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error(`Model returned no JSON payload: ${text.slice(0, 300)}`);
  }

  const parsed = JSON.parse(jsonMatch[0]) as Record<string, unknown>;
  const currents = Array.isArray(parsed.currents)
    ? parsed.currents.map((current) => normalizeCurrent(current))
    : undefined;

  return {
    title: typeof parsed.title === "string" ? parsed.title : undefined,
    body_markdown: typeof parsed.body_markdown === "string" ? parsed.body_markdown : undefined,
    currents,
  };
}

function normalizeCurrent(current: unknown) {
  const data = current && typeof current === "object" ? (current as Record<string, unknown>) : {};

  return {
    name: typeof data.name === "string" ? data.name : undefined,
    score: typeof data.score === "number" ? data.score : Number(data.score || 0) || undefined,
    summary: typeof data.summary === "string" ? data.summary : undefined,
    signals: Array.isArray(data.signals)
      ? data.signals.filter((signal): signal is string => typeof signal === "string")
      : undefined,
  };
}
