type SavePayload = Record<string, unknown>;

// Placeholder side-effect hook for explicit user-intent saves.
export async function saveTipForUser(
  _userId: number,
  _coachSessionId: number,
  _payload: SavePayload,
): Promise<void> {
  return Promise.resolve();
}
