export const CoachEventNames = {
  streamStarted: "stream_started",
  assistantDelta: "assistant_delta",
  assistantDone: "assistant_done",
  streamStopped: "stream_stopped",
  error: "error",
} as const;

export type CoachEventName = (typeof CoachEventNames)[keyof typeof CoachEventNames];

export type CoachActionType = "recommend_tip" | "save_tip" | "dismiss_tip" | "complete_onboarding";

export type CoachAction = {
  type: CoachActionType;
  payload: Record<string, unknown>;
};

export type CoachRespondRequest = {
  requestId: string;
  transport: "app";
  userId: number;
  coachSessionId: number;
  phase: "onboarding" | "pre_round" | "during_round" | "post_round";
  message: string;
  context: Record<string, unknown>;
};

export type CoachRespondResponse = {
  requestId: string;
  text: string;
  actions: CoachAction[];
  profileUpdates?: Record<string, unknown>;
};
