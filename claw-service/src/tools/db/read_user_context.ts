type ContextPayload = Record<string, unknown>;

// This intentionally stays transport-agnostic: in production wire to
// a private Rails endpoint or direct DB adapter with user-scoped filters.
export async function readUserContext(
  userId: number,
  coachSessionId: number,
  context: ContextPayload,
): Promise<ContextPayload> {
  return {
    user_id: userId,
    coach_session_id: coachSessionId,
    ...context,
  };
}
