type ArtifactPayload = {
  requestId: string;
  requestText: string;
  responseText: string;
  profileUpdates: Record<string, unknown>;
};

// Placeholder for persistent artifact storage.
// Recommended production implementation:
// - append immutable audit events
// - write user-scoped profile deltas
// - emit observability events with requestId
export async function writeCoachArtifacts(
  _userId: number,
  _coachSessionId: number,
  _artifacts: ArtifactPayload,
): Promise<void> {
  return Promise.resolve();
}
