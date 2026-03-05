import consumer from "channels/consumer";

export function subscribeToCoachSession(coachSessionId, callbacks = {}) {
  return consumer.subscriptions.create(
    { channel: "CoachSessionChannel", coach_session_id: coachSessionId },
    {
      connected() {
        callbacks.connected?.();
      },

      disconnected() {
        callbacks.disconnected?.();
      },

      received(data) {
        callbacks.received?.(data);
      },
    },
  );
}
