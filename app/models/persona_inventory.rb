module PersonaInventory
  Slot = Data.define(
    :key,
    :group,
    :label,
    :prompt,
    :short_prompt,
    :options,
    :multi_select,
    :allow_freeform,
    :max_options
  )

  GROUPS = %w[values priorities preferences likes dislikes].freeze

  SLOTS = [
    Slot.new(
      key: "core_values",
      group: "values",
      label: "Core values",
      prompt: "Quick check — which values feel most central to how you want to live right now? Pick a few that resonate, or share your own.",
      short_prompt: "Pick the values that feel most central right now",
      options: [
        "Family",
        "Growth",
        "Health",
        "Creativity",
        "Freedom",
        "Stability",
        "Service",
        "Adventure",
        "Honesty",
        "Curiosity"
      ],
      multi_select: true,
      allow_freeform: true,
      max_options: 4
    ),
    Slot.new(
      key: "top_priorities",
      group: "priorities",
      label: "Top priorities",
      prompt: "What are your top priorities over the next few months? Choose what feels alive right now.",
      short_prompt: "Pick the priorities that matter most over the next few months",
      options: [
        "Career",
        "Relationships",
        "Physical health",
        "Mental wellbeing",
        "Finances",
        "Learning",
        "Hobbies",
        "Rest"
      ],
      multi_select: true,
      allow_freeform: true,
      max_options: 4
    ),
    Slot.new(
      key: "energy_window",
      group: "preferences",
      label: "Energy window",
      prompt: "When in the day do you feel most energized and clear-headed?",
      short_prompt: "When you feel most energized",
      options: [
        "Early morning",
        "Mid-morning",
        "Afternoon",
        "Evening",
        "Late night",
        "It varies a lot"
      ],
      multi_select: false,
      allow_freeform: true,
      max_options: 1
    ),
    Slot.new(
      key: "social_rhythm",
      group: "preferences",
      label: "Social rhythm",
      prompt: "How would you describe your social rhythm right now?",
      short_prompt: "Your social rhythm",
      options: [
        "Need a lot of solo time",
        "Energized by small groups",
        "Thrive in big groups",
        "It depends on the day"
      ],
      multi_select: false,
      allow_freeform: true,
      max_options: 1
    ),
    Slot.new(
      key: "decision_style",
      group: "preferences",
      label: "Decision style",
      prompt: "When you make important decisions, what do you trust most?",
      short_prompt: "What you trust most when deciding",
      options: [
        "Logic and data",
        "Intuition and gut",
        "Trusted advisors",
        "Lived experience"
      ],
      multi_select: false,
      allow_freeform: true,
      max_options: 1
    ),
    Slot.new(
      key: "likes",
      group: "likes",
      label: "What energizes you",
      prompt: "What do you genuinely look forward to in a typical week? Pick a few or add your own.",
      short_prompt: "What you look forward to",
      options: [
        "Time outdoors",
        "Cooking or food",
        "Reading",
        "Music",
        "Workouts",
        "Long walks",
        "Quiet time",
        "Creative projects",
        "Time with friends"
      ],
      multi_select: true,
      allow_freeform: true,
      max_options: 4
    ),
    Slot.new(
      key: "dislikes",
      group: "dislikes",
      label: "What drains you",
      prompt: "What drains you fastest? Pick what fits — it helps me steer around your sore spots.",
      short_prompt: "What drains you fastest",
      options: [
        "Long meetings",
        "Small talk",
        "Disorganization",
        "Ambiguity",
        "Repetition",
        "Conflict",
        "Rushing",
        "Sitting still"
      ],
      multi_select: true,
      allow_freeform: true,
      max_options: 4
    )
  ].freeze

  SLOTS_BY_KEY = SLOTS.index_by(&:key).freeze

  module_function

  def keys
    SLOTS.map(&:key)
  end

  def find(key)
    SLOTS_BY_KEY[key.to_s]
  end

  def slot_payload(slot)
    return nil unless slot

    {
      slot: slot.key,
      group: slot.group,
      label: slot.label,
      question: slot.prompt,
      short_prompt: slot.short_prompt,
      options: slot.options,
      multi_select: slot.multi_select,
      allow_freeform: slot.allow_freeform,
      max_options: slot.max_options
    }
  end
end
