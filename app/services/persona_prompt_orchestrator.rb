class PersonaPromptOrchestrator
  COOLDOWN_SECONDS = 90
  RECENT_LOOKBACK = 6

  def initialize(user:, coach_session: nil, now: Time.current)
    @user = user
    @coach_session = coach_session
    @now = now
  end

  def should_offer_prompt?
    return false unless eligible_user?
    return false if recent_persona_prompt?
    return false if next_payload.nil?

    true
  end

  def next_payload
    return dilemma_payload if dilemma_payload

    inventory_service.next_prompt_payload&.then { |payload| inventory_to_prompt(payload) }
  end

  def dilemma_service
    @dilemma_service ||= PersonaDilemmaService.new(user: @user, coach_session: @coach_session, now: @now)
  end

  def inventory_service
    @inventory_service ||= PersonaQuestionService.new(user: @user, coach_session: @coach_session, now: @now)
  end

  private

  def eligible_user?
    @user.present? && @user.respond_to?(:life?) && @user.life?
  end

  def dilemma_payload
    return @dilemma_payload if defined?(@dilemma_payload)

    @dilemma_payload = dilemma_service.next_payload&.merge(
      max_options: 1,
      allow_skip: true
    )
  end

  def inventory_to_prompt(slot_payload)
    {
      kind: "persona_question",
      slot: slot_payload[:slot],
      group: slot_payload[:group],
      label: slot_payload[:label],
      question: slot_payload[:question],
      short_prompt: slot_payload[:short_prompt],
      options: slot_payload[:options].map { |opt| { id: opt, label: opt } },
      multi_select: slot_payload[:multi_select],
      allow_freeform: slot_payload[:allow_freeform],
      max_options: slot_payload[:max_options],
      allow_skip: true
    }
  end

  def recent_persona_prompt?
    return false unless @coach_session

    recent = @coach_session.coach_messages
                           .assistant
                           .order(created_at: :desc)
                           .limit(RECENT_LOOKBACK)

    recent.any? do |message|
      prompt = message.metadata.is_a?(Hash) ? message.metadata["prompt"] : nil
      next false unless prompt.is_a?(Hash)
      next false unless %w[persona_question persona_dilemma].include?(prompt["kind"])

      created = message.created_at || @now
      created > @now - COOLDOWN_SECONDS.seconds
    end
  end
end
