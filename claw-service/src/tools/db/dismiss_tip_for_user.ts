type DismissPayload = Record<string, unknown>;

// Placeholder side-effect hook for explicit dismiss actions.
export async function dismissTipForUser(
  _userId: number,
  _coachSessionId: number,
  _payload: DismissPayload,
): Promise<void> {
  return Promise.resolve();
}
