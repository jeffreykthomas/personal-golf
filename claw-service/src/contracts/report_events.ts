export type SelfUnderstandingReportCurrent = {
  name?: string;
  score?: number;
  summary?: string;
  signals?: string[];
};

export type SelfUnderstandingReportPayload = {
  title?: string;
  body_markdown?: string;
  currents?: SelfUnderstandingReportCurrent[];
};

export type SelfUnderstandingReportRespondRequest = {
  requestId: string;
  transport: "app";
  userId: number;
  sourceDigest: string;
  prompt: string;
};

export type SelfUnderstandingReportRespondResponse = {
  requestId: string;
  report: SelfUnderstandingReportPayload;
};

export type PendingSelfUnderstandingReportTask = {
  user_id: number;
  source_digest: string;
  framework_name: string;
  current_order: string[];
  prompt: string;
  source_updated_at?: string;
};

export type PendingSelfUnderstandingReportsResponse = {
  tasks: PendingSelfUnderstandingReportTask[];
};

export type PersistSelfUnderstandingReportRequest = {
  user_id: number;
  source_digest: string;
  report: SelfUnderstandingReportPayload;
};

export type PersistSelfUnderstandingReportResponse = {
  status: "created" | "updated" | "skipped" | "stale";
  report_id?: number;
  reason?: string;
  expected_source_digest?: string;
};
