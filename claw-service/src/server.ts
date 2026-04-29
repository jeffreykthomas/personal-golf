import { createServer, IncomingMessage, ServerResponse } from "node:http";
import { CoachRespondRequest, CoachRespondResponse } from "./contracts/coach_events";
import {
  SelfUnderstandingReportRespondRequest,
  SelfUnderstandingReportRespondResponse,
} from "./contracts/report_events";
import { readUserContext } from "./tools/db/read_user_context";
import { recommendTip } from "./tools/db/recommend_tip";
import { saveTipForUser } from "./tools/db/save_tip_for_user";
import { dismissTipForUser } from "./tools/db/dismiss_tip_for_user";
import { writeCoachArtifacts } from "./tools/db/write_coach_artifacts";
import { generateSelfUnderstandingReport } from "./report_generation";
import { syncSelfUnderstandingReportsOnce } from "./report_sync";

const PORT = Number(process.env.CLAW_SIBLING_PORT || 4317);
const AUTH_TOKEN = process.env.CLAW_SIBLING_TOKEN || "";
const AUTO_SELF_UNDERSTANDING_REPORTS_ENABLED = process.env.AUTO_SELF_UNDERSTANDING_REPORTS_ENABLED === "true";
const SELF_UNDERSTANDING_REPORT_INTERVAL_MS = Number(
  process.env.SELF_UNDERSTANDING_REPORT_INTERVAL_MS || 86_400_000,
);

function sendJson(res: ServerResponse, status: number, payload: Record<string, unknown>): void {
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json");
  res.end(JSON.stringify(payload));
}

async function parseJson<T>(req: IncomingMessage): Promise<T> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return JSON.parse(Buffer.concat(chunks).toString("utf8")) as T;
}

function unauthorized(req: IncomingMessage): boolean {
  if (!AUTH_TOKEN) return false;
  const auth = req.headers.authorization || "";
  return auth !== `Bearer ${AUTH_TOKEN}`;
}

function inferResponse(request: CoachRespondRequest, userContext: Record<string, unknown>): CoachRespondResponse {
  const text = request.message.toLowerCase();
  const actions: CoachRespondResponse["actions"] = [];
  const profileUpdates: Record<string, unknown> = {};

  if (request.phase === "onboarding") {
    profileUpdates.lastOnboardingReply = request.message;
    if (text.includes("beginner") || text.includes("intermediate") || text.includes("advanced")) {
      profileUpdates.skillLevel = text.includes("advanced")
        ? "advanced"
        : text.includes("intermediate")
          ? "intermediate"
          : "beginner";
    }
  }

  if (text.includes("save") && text.includes("tip")) {
    actions.push({ type: "save_tip", payload: {} });
    return {
      requestId: request.requestId,
      text: "I can save your most recent recommended tip now.",
      actions,
      profileUpdates,
    };
  }

  if (text.includes("dismiss") && text.includes("tip")) {
    actions.push({ type: "dismiss_tip", payload: {} });
    return {
      requestId: request.requestId,
      text: "I can dismiss that tip and move on.",
      actions,
      profileUpdates,
    };
  }

  if (text.includes("tip") || text.includes("advice") || text.includes("recommend")) {
    const title = "Commit to one miss";
    const content = "Choose your safe miss before every full shot and swing with full commitment to reduce doubles.";
    actions.push({
      type: "recommend_tip",
      payload: {
        title,
        content,
        phase: request.phase === "post_round" ? "post_round" : "during_round",
        category_slug: request.phase === "during_round" ? "course-tip" : "basics",
      },
    });

    return {
      requestId: request.requestId,
      text: "I generated a focused tip for you. Save it if you want to keep it.",
      actions,
      profileUpdates,
    };
  }

  const hole = userContext.hole_number ? ` hole ${userContext.hole_number}` : "";
  return {
    requestId: request.requestId,
    text: `Coach is with you${hole}. Ask for a tip, prep plan, or post-round debrief.`,
    actions,
    profileUpdates,
  };
}

async function handleCoachRequest(req: IncomingMessage, res: ServerResponse): Promise<void> {
  const payload = await parseJson<CoachRespondRequest>(req);
  if (payload.transport !== "app") {
    sendJson(res, 422, { error: "unsupported_transport" });
    return;
  }
  const userContext = await readUserContext(payload.userId, payload.coachSessionId, payload.context);
  const response = inferResponse(payload, userContext);

  await writeCoachArtifacts(payload.userId, payload.coachSessionId, {
    requestId: payload.requestId,
    requestText: payload.message,
    responseText: response.text,
    profileUpdates: response.profileUpdates || {},
  });

  for (const action of response.actions) {
    if (action.type === "recommend_tip") {
      await recommendTip(payload.userId, payload.coachSessionId, action.payload);
    } else if (action.type === "save_tip") {
      await saveTipForUser(payload.userId, payload.coachSessionId, action.payload);
    } else if (action.type === "dismiss_tip") {
      await dismissTipForUser(payload.userId, payload.coachSessionId, action.payload);
    }
  }

  sendJson(res, 200, response as unknown as Record<string, unknown>);
}

async function handleReportRequest(req: IncomingMessage, res: ServerResponse): Promise<void> {
  const payload = await parseJson<SelfUnderstandingReportRespondRequest>(req);
  if (payload.transport !== "app") {
    sendJson(res, 422, { error: "unsupported_transport" });
    return;
  }

  const response = await generateSelfUnderstandingReport(payload);
  sendJson(res, 200, response as unknown as Record<string, unknown>);
}

function startSelfUnderstandingReportLoop(): void {
  if (!AUTO_SELF_UNDERSTANDING_REPORTS_ENABLED) {
    return;
  }

  let running = false;
  const runSync = async () => {
    if (running) {
      return;
    }

    running = true;
    try {
      await syncSelfUnderstandingReportsOnce();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(`Self-understanding report sync loop failed: ${(error as Error).message}`);
    } finally {
      running = false;
    }
  };

  setTimeout(() => {
    void runSync();
  }, 1_000);

  setInterval(() => {
    void runSync();
  }, SELF_UNDERSTANDING_REPORT_INTERVAL_MS);
}

createServer(async (req, res) => {
  if (unauthorized(req)) {
    sendJson(res, 401, { error: "unauthorized" });
    return;
  }

  try {
    if (req.method === "POST" && req.url === "/v1/coach/respond") {
      await handleCoachRequest(req, res);
      return;
    }

    if (req.method === "POST" && req.url === "/v1/report/respond") {
      await handleReportRequest(req, res);
      return;
    }

    sendJson(res, 404, { error: "not_found" });
  } catch (error) {
    sendJson(res, 422, { error: (error as Error).message });
  }
}).listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Sibling Claw service listening on ${PORT}`);
  startSelfUnderstandingReportLoop();
});
