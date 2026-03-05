module Coach
  module EventContract
    STREAM_STARTED = "stream_started".freeze
    ASSISTANT_DELTA = "assistant_delta".freeze
    ASSISTANT_DONE = "assistant_done".freeze
    STREAM_STOPPED = "stream_stopped".freeze
    ERROR = "error".freeze

    EVENT_NAMES = [
      STREAM_STARTED,
      ASSISTANT_DELTA,
      ASSISTANT_DONE,
      STREAM_STOPPED,
      ERROR
    ].freeze

    module_function

    def stream_started(request_id:, session_id:)
      {
        event: STREAM_STARTED,
        request_id: request_id,
        session_id: session_id
      }
    end

    def assistant_delta(request_id:, session_id:, delta:, sequence:)
      {
        event: ASSISTANT_DELTA,
        request_id: request_id,
        session_id: session_id,
        delta: delta,
        sequence: sequence
      }
    end

    def assistant_done(request_id:, session_id:, message:, actions: [])
      {
        event: ASSISTANT_DONE,
        request_id: request_id,
        session_id: session_id,
        message: message,
        actions: actions
      }
    end

    def stream_stopped(request_id:, session_id:, reason:)
      {
        event: STREAM_STOPPED,
        request_id: request_id,
        session_id: session_id,
        reason: reason
      }
    end

    def error(request_id:, session_id:, code:, message:)
      {
        event: ERROR,
        request_id: request_id,
        session_id: session_id,
        code: code,
        message: message
      }
    end
  end
end
