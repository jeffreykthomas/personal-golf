type RecommendPayload = Record<string, unknown>;

// Placeholder side-effect hook.
// Rails currently performs authoritative tip persistence, while this tool can
// be upgraded to call private Rails endpoints for proactive writes.
export async function recommendTip(
  _userId: number,
  _coachSessionId: number,
  _payload: RecommendPayload,
): Promise<void> {
  return Promise.resolve();
}
