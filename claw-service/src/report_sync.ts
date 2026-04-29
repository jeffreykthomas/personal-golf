import { randomUUID } from "node:crypto";
import { pathToFileURL } from "node:url";
import {
  PendingSelfUnderstandingReportsResponse,
  PersistSelfUnderstandingReportRequest,
  PersistSelfUnderstandingReportResponse,
  SelfUnderstandingReportRespondRequest,
} from "./contracts/report_events";
import { generateSelfUnderstandingReport } from "./report_generation";

const DEFAULT_APP_URL = process.env.COACH_APP_URL || "http://127.0.0.1:3000";
const DEFAULT_BATCH_SIZE = Number(process.env.SELF_UNDERSTANDING_REPORT_BATCH_SIZE || 3);

type Logger = Pick<Console, "info" | "error">;

export async function syncSelfUnderstandingReportsOnce(
  options: { limit?: number; logger?: Logger } = {},
): Promise<{
  fetched: number;
  created: number;
  updated: number;
  skipped: number;
  stale: number;
  failed: number;
}> {
  const logger = options.logger || console;
  const tasks = await fetchPendingTasks(options.limit || DEFAULT_BATCH_SIZE);
  const summary = {
    fetched: tasks.tasks.length,
    created: 0,
    updated: 0,
    skipped: 0,
    stale: 0,
    failed: 0,
  };

  for (const task of tasks.tasks) {
    try {
      const generated = await generateSelfUnderstandingReport({
        requestId: randomUUID(),
        transport: "app",
        userId: task.user_id,
        sourceDigest: task.source_digest,
        prompt: task.prompt,
      } satisfies SelfUnderstandingReportRespondRequest);

      const persisted = await persistReport({
        user_id: task.user_id,
        source_digest: task.source_digest,
        report: generated.report,
      });

      if (persisted.status === "created") {
        summary.created += 1;
      } else if (persisted.status === "updated") {
        summary.updated += 1;
      } else if (persisted.status === "stale") {
        summary.stale += 1;
      } else {
        summary.skipped += 1;
      }
    } catch (error) {
      summary.failed += 1;
      logger.error(
        `Self-understanding report sync failed user=${task.user_id} digest=${task.source_digest}: ${(error as Error).message}`,
      );
    }
  }

  logger.info(
    `Self-understanding report sync finished fetched=${summary.fetched} created=${summary.created} updated=${summary.updated} skipped=${summary.skipped} stale=${summary.stale} failed=${summary.failed}`,
  );

  return summary;
}

async function fetchPendingTasks(limit: number): Promise<PendingSelfUnderstandingReportsResponse> {
  const url = new URL("/internal/self_understanding_reports/pending", DEFAULT_APP_URL);
  url.searchParams.set("limit", String(limit));

  const response = await fetch(url, {
    headers: appHeaders(),
  });
  const rawText = await response.text();

  if (!response.ok) {
    throw new Error(`Pending report fetch failed: ${response.status} ${rawText.slice(0, 300)}`);
  }

  return JSON.parse(rawText) as PendingSelfUnderstandingReportsResponse;
}

async function persistReport(
  payload: PersistSelfUnderstandingReportRequest,
): Promise<PersistSelfUnderstandingReportResponse> {
  const response = await fetch(new URL("/internal/self_understanding_reports", DEFAULT_APP_URL), {
    method: "POST",
    headers: appHeaders(),
    body: JSON.stringify(payload),
  });
  const rawText = await response.text();
  const body = rawText ? (JSON.parse(rawText) as PersistSelfUnderstandingReportResponse) : { status: "skipped" as const };

  if (!response.ok && response.status !== 409) {
    throw new Error(`Report persist failed: ${response.status} ${rawText.slice(0, 300)}`);
  }

  return response.status === 409 ? { ...body, status: "stale" } : body;
}

function appHeaders(): Record<string, string> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  const token = process.env.CLAW_SIBLING_TOKEN || "";
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  return headers;
}

async function runFromCli() {
  await syncSelfUnderstandingReportsOnce();
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runFromCli().catch((error) => {
    // eslint-disable-next-line no-console
    console.error((error as Error).message);
    process.exitCode = 1;
  });
}
