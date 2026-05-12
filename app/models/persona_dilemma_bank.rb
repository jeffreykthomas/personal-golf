module PersonaDilemmaBank
  Option = Data.define(:id, :label, :signals)

  Dilemma = Data.define(
    :id,
    :category,
    :title,
    :scenario,
    :short_prompt,
    :options,
    :tags
  )

  CATEGORIES = %w[
    values
    priorities
    beliefs
    fears
    strengths
    weaknesses
    preferences
  ].freeze

  DILEMMAS = [
    Dilemma.new(
      id: "values_honesty_vs_kindness_pitch",
      category: "values",
      title: "A friend's flawed pitch",
      scenario: "A close friend asks you to read their startup pitch the night before a high-stakes meeting. You can see a fundamental flaw they've missed — the kind that will sink the room and probably embarrass them.",
      short_prompt: "What do you actually do?",
      options: [
        Option.new(
          id: "tell_straight",
          label: "Tell them straight — better the sting tonight than the fall tomorrow.",
          signals: {
            "values" => { "honesty" => 1.0, "courage" => 0.5 },
            "strengths" => { "directness" => 0.6 }
          }
        ),
        Option.new(
          id: "soften",
          label: "Flag the weak spots gently — protect their confidence going in.",
          signals: {
            "values" => { "kindness" => 1.0, "harmony" => 0.5 },
            "fears" => { "causing_harm" => 0.4 }
          }
        ),
        Option.new(
          id: "ask_first",
          label: "Ask what they want first — feedback or a confidence boost.",
          signals: {
            "values" => { "respect_for_autonomy" => 1.0 },
            "strengths" => { "thoughtfulness" => 0.7 },
            "preferences" => { "consent_first" => 0.5 }
          }
        )
      ],
      tags: [ "relationships", "feedback" ]
    ),

    Dilemma.new(
      id: "values_loyalty_vs_justice_colleague",
      category: "values",
      title: "A loyal friend, a real harm",
      scenario: "A close colleague — and friend — made a serious mistake at work that quietly hurt several other people. They haven't told anyone. Owning up will likely cost them their role.",
      short_prompt: "Where do you land?",
      options: [
        Option.new(
          id: "report",
          label: "Surface it through the right channel. People deserve to know.",
          signals: {
            "values" => { "justice" => 1.0, "integrity" => 0.6 },
            "strengths" => { "moral_courage" => 0.6 }
          }
        ),
        Option.new(
          id: "push_them",
          label: "Tell them they need to come forward — and give them a deadline.",
          signals: {
            "values" => { "integrity" => 1.0, "loyalty" => 0.5 },
            "preferences" => { "agency_first" => 0.6 }
          }
        ),
        Option.new(
          id: "stay_quiet",
          label: "Stay quiet — it's their call to make and theirs alone.",
          signals: {
            "values" => { "loyalty" => 1.0, "discretion" => 0.5 },
            "fears" => { "betraying_trust" => 0.6 }
          }
        )
      ],
      tags: [ "ethics", "work" ]
    ),

    Dilemma.new(
      id: "values_freedom_vs_security_career",
      category: "values",
      title: "Stable seat or wild swing",
      scenario: "You're offered a senior role at a steady company and a one-year runway to bet on a project you've been quietly building. The numbers say take the role. Your gut keeps drifting.",
      short_prompt: "Which way do you go?",
      options: [
        Option.new(
          id: "take_role",
          label: "Take the role. Build the project on the side.",
          signals: {
            "values" => { "stability" => 1.0, "responsibility" => 0.5 },
            "fears" => { "instability" => 0.6 },
            "preferences" => { "compounding_safety" => 0.5 }
          }
        ),
        Option.new(
          id: "swing",
          label: "Take the swing. You've earned the year.",
          signals: {
            "values" => { "freedom" => 1.0, "self_authorship" => 0.7 },
            "strengths" => { "risk_tolerance" => 0.7 }
          }
        ),
        Option.new(
          id: "negotiate",
          label: "Try to engineer a hybrid — part-time role, real time for the project.",
          signals: {
            "values" => { "creativity" => 0.7, "pragmatism" => 0.6 },
            "strengths" => { "negotiation" => 0.6 }
          }
        )
      ],
      tags: [ "career" ]
    ),

    Dilemma.new(
      id: "values_tradition_vs_progress_family",
      category: "values",
      title: "A path your family didn't picture",
      scenario: "You're considering a life choice that sits well with you but breaks an unspoken expectation your family has carried for years.",
      short_prompt: "How do you handle the conversation?",
      options: [
        Option.new(
          id: "make_choice_explain_later",
          label: "Make the choice first. Explain once it's real.",
          signals: {
            "values" => { "self_authorship" => 1.0, "freedom" => 0.5 },
            "strengths" => { "decisiveness" => 0.6 }
          }
        ),
        Option.new(
          id: "long_conversation_first",
          label: "Sit with them first. The choice can wait until they understand.",
          signals: {
            "values" => { "connection" => 1.0, "tradition" => 0.5 },
            "strengths" => { "patience" => 0.6 }
          }
        ),
        Option.new(
          id: "find_a_third_path",
          label: "Look for a third path that honors both.",
          signals: {
            "values" => { "integration" => 1.0 },
            "strengths" => { "creativity" => 0.6 }
          }
        )
      ],
      tags: [ "family" ]
    ),

    Dilemma.new(
      id: "values_quick_honesty_vs_kindness",
      category: "values",
      title: "Honesty or kindness",
      scenario: nil,
      short_prompt: "When the two pull apart, which usually wins?",
      options: [
        Option.new(
          id: "honesty",
          label: "Honesty.",
          signals: { "values" => { "honesty" => 1.0 } }
        ),
        Option.new(
          id: "kindness",
          label: "Kindness.",
          signals: { "values" => { "kindness" => 1.0 } }
        ),
        Option.new(
          id: "depends",
          label: "Depends on the stakes.",
          signals: {
            "values" => { "context_sensitivity" => 1.0 },
            "preferences" => { "situational_thinking" => 0.5 }
          }
        )
      ],
      tags: [ "comparison" ]
    ),

    Dilemma.new(
      id: "values_quick_freedom_vs_belonging",
      category: "values",
      title: "Freedom or belonging",
      scenario: nil,
      short_prompt: "If you had to choose right now?",
      options: [
        Option.new(
          id: "freedom",
          label: "Freedom.",
          signals: { "values" => { "freedom" => 1.0 } }
        ),
        Option.new(
          id: "belonging",
          label: "Belonging.",
          signals: { "values" => { "belonging" => 1.0, "connection" => 0.5 } }
        )
      ],
      tags: [ "comparison" ]
    ),

    Dilemma.new(
      id: "priorities_health_vs_achievement",
      category: "priorities",
      title: "The body sends a warning",
      scenario: "You're three weeks into a hard sprint and your body is starting to talk: poor sleep, tight chest, low patience. The deadline is real and only ten days out.",
      short_prompt: "What do you do this week?",
      options: [
        Option.new(
          id: "push_through",
          label: "Push through. You can recover after the deadline.",
          signals: {
            "priorities" => { "achievement" => 1.0 },
            "values" => { "drive" => 0.6 },
            "weaknesses" => { "ignoring_body_signals" => 0.6 }
          }
        ),
        Option.new(
          id: "scale_back",
          label: "Scale the scope. Hit the deadline at 80%, keep yourself intact.",
          signals: {
            "priorities" => { "health" => 1.0 },
            "strengths" => { "self_regulation" => 0.6 }
          }
        ),
        Option.new(
          id: "ask_for_help",
          label: "Pull someone else in to share the load.",
          signals: {
            "priorities" => { "sustainability" => 1.0 },
            "strengths" => { "asking_for_help" => 0.7 }
          }
        )
      ],
      tags: [ "health", "work" ]
    ),

    Dilemma.new(
      id: "priorities_career_vs_relationship",
      category: "priorities",
      title: "Two thousand miles of decision",
      scenario: "You're offered a role you've wanted for years, two thousand miles from where your partner has just started building real momentum in their own work.",
      short_prompt: "What do you reach for first?",
      options: [
        Option.new(
          id: "take_it",
          label: "Take it. Find out together how to make it work.",
          signals: {
            "priorities" => { "career" => 1.0 },
            "values" => { "ambition" => 0.6 }
          }
        ),
        Option.new(
          id: "decline",
          label: "Decline. Their momentum is real and the next door will open.",
          signals: {
            "priorities" => { "relationships" => 1.0 },
            "values" => { "loyalty" => 0.6 }
          }
        ),
        Option.new(
          id: "negotiate_remote",
          label: "Try to negotiate remote, partial relocation, anything that holds both.",
          signals: {
            "priorities" => { "integration" => 1.0 },
            "strengths" => { "negotiation" => 0.6 }
          }
        )
      ],
      tags: [ "relationships", "career" ]
    ),

    Dilemma.new(
      id: "priorities_now_vs_future_windfall",
      category: "priorities",
      title: "An unexpected windfall",
      scenario: "You receive a one-time $20k that you weren't counting on.",
      short_prompt: "What's the first thing you reach for?",
      options: [
        Option.new(
          id: "experience",
          label: "Spend a chunk on something that becomes a memory.",
          signals: {
            "priorities" => { "present" => 1.0 },
            "values" => { "experience" => 0.6 }
          }
        ),
        Option.new(
          id: "invest",
          label: "Invest most of it. Future-me wins.",
          signals: {
            "priorities" => { "future" => 1.0 },
            "values" => { "stability" => 0.5 }
          }
        ),
        Option.new(
          id: "give",
          label: "Set a slice aside for someone or something that needs it more.",
          signals: {
            "priorities" => { "service" => 1.0 },
            "values" => { "generosity" => 0.6 }
          }
        )
      ],
      tags: [ "money" ]
    ),

    Dilemma.new(
      id: "beliefs_effort_vs_talent_kid",
      category: "beliefs",
      title: "What you'd tell a kid",
      scenario: "A kid you care about is discouraged because someone in their class is 'naturally good' at the thing they love. They're starting to think they don't have it.",
      short_prompt: "What's closer to what you'd actually say?",
      options: [
        Option.new(
          id: "effort",
          label: "Talent's mostly a head start. Sustained practice catches up.",
          signals: {
            "beliefs" => { "effort_over_talent" => 1.0 },
            "values" => { "perseverance" => 0.6 }
          }
        ),
        Option.new(
          id: "fit",
          label: "Some things fit you and some don't — find the one where you feel pulled.",
          signals: {
            "beliefs" => { "fit_over_force" => 1.0 },
            "values" => { "authenticity" => 0.6 }
          }
        ),
        Option.new(
          id: "both",
          label: "Both matter — talent gets you started, effort decides where you end up.",
          signals: {
            "beliefs" => { "balanced_view" => 1.0 },
            "preferences" => { "nuance" => 0.5 }
          }
        )
      ],
      tags: [ "growth" ]
    ),

    Dilemma.new(
      id: "beliefs_agency_vs_circumstance",
      category: "beliefs",
      title: "A friend stuck somewhere hard",
      scenario: "A friend keeps landing in the same hard situation. They tell you again, and you can hear how much of it is circumstance and how much is choices that compound.",
      short_prompt: "What story do you carry into the conversation?",
      options: [
        Option.new(
          id: "agency",
          label: "Mostly choices. Even small moves change the trajectory.",
          signals: {
            "beliefs" => { "agency_first" => 1.0 },
            "values" => { "responsibility" => 0.6 }
          }
        ),
        Option.new(
          id: "circumstance",
          label: "Mostly circumstance. The system makes it hard to move.",
          signals: {
            "beliefs" => { "systems_first" => 1.0 },
            "values" => { "compassion" => 0.6 }
          }
        ),
        Option.new(
          id: "both_real",
          label: "Both, honestly — and the work is figuring out which lever they actually have.",
          signals: {
            "beliefs" => { "integrated_view" => 1.0 },
            "strengths" => { "discernment" => 0.6 }
          }
        )
      ],
      tags: [ "ethics", "growth" ]
    ),

    Dilemma.new(
      id: "fears_failure_vs_regret",
      category: "fears",
      title: "The leap you keep weighing",
      scenario: "There's a thing you've been quietly considering for over a year — a leap that could matter or could land badly. You haven't moved.",
      short_prompt: "What's the louder voice when you're alone with it?",
      options: [
        Option.new(
          id: "fear_failure",
          label: "What if I try and it doesn't work — what does that mean about me?",
          signals: {
            "fears" => { "failure" => 1.0, "identity_loss" => 0.6 }
          }
        ),
        Option.new(
          id: "fear_regret",
          label: "What if I never try and I have to live with the not-knowing?",
          signals: {
            "fears" => { "regret" => 1.0 },
            "values" => { "self_authorship" => 0.5 }
          }
        ),
        Option.new(
          id: "fear_disrupting",
          label: "What if it works and disrupts everything I've already built?",
          signals: {
            "fears" => { "disruption" => 1.0 },
            "values" => { "stability" => 0.5 }
          }
        )
      ],
      tags: [ "growth" ]
    ),

    Dilemma.new(
      id: "fears_judgement_vs_invisibility",
      category: "fears",
      title: "The work you haven't shown",
      scenario: "There's a creative or personal piece you've been working on. It isn't polished. You're sitting on it.",
      short_prompt: "What's actually keeping it in the drawer?",
      options: [
        Option.new(
          id: "judgement",
          label: "I don't want it picked apart while it's still raw.",
          signals: {
            "fears" => { "judgement" => 1.0 },
            "preferences" => { "polish_before_share" => 0.6 }
          }
        ),
        Option.new(
          id: "invisibility",
          label: "I'm afraid I'll share it and nothing will happen.",
          signals: {
            "fears" => { "invisibility" => 1.0 }
          }
        ),
        Option.new(
          id: "not_done",
          label: "I genuinely think it isn't done yet.",
          signals: {
            "values" => { "craft" => 1.0 },
            "preferences" => { "high_standard" => 0.5 }
          }
        )
      ],
      tags: [ "creativity" ]
    ),

    Dilemma.new(
      id: "strengths_group_dynamics",
      category: "strengths",
      title: "A meeting going off the rails",
      scenario: "A group decision is drifting. Voices are talking past each other, time is bleeding, and the actual question hasn't been named.",
      short_prompt: "What's the move that comes most naturally to you?",
      options: [
        Option.new(
          id: "take_charge",
          label: "Step in and name the question. Drive it to a decision.",
          signals: {
            "strengths" => { "leadership" => 1.0, "directness" => 0.6 }
          }
        ),
        Option.new(
          id: "mediate",
          label: "Slow it down. Make sure the quieter voices land before deciding.",
          signals: {
            "strengths" => { "facilitation" => 1.0, "empathy" => 0.6 }
          }
        ),
        Option.new(
          id: "observe",
          label: "Stay back and read the room. Speak only when the right moment arrives.",
          signals: {
            "strengths" => { "discernment" => 1.0, "patience" => 0.5 }
          }
        )
      ],
      tags: [ "groups" ]
    ),

    Dilemma.new(
      id: "strengths_friend_in_tears",
      category: "strengths",
      title: "A friend in tears",
      scenario: "A close friend calls you in tears. They haven't asked for anything specific yet.",
      short_prompt: "What do you do first?",
      options: [
        Option.new(
          id: "solve",
          label: "Try to understand what's happening so you can actually help fix it.",
          signals: {
            "strengths" => { "problem_solving" => 1.0 },
            "preferences" => { "action_orientation" => 0.5 }
          }
        ),
        Option.new(
          id: "sit",
          label: "Just be present. Let them feel it without pulling them out of it.",
          signals: {
            "strengths" => { "emotional_steadiness" => 1.0, "empathy" => 0.7 }
          }
        ),
        Option.new(
          id: "ground",
          label: "Help them slow their breathing and find the next small step.",
          signals: {
            "strengths" => { "grounding" => 1.0 },
            "preferences" => { "step_by_step" => 0.5 }
          }
        )
      ],
      tags: [ "relationships" ]
    ),

    Dilemma.new(
      id: "weaknesses_under_stress",
      category: "weaknesses",
      title: "When you're tired and stretched",
      scenario: "Imagine you're at the end of a long, draining stretch — short on sleep, behind on things, and someone close needs something from you.",
      short_prompt: "Which slip is most likely to show up first?",
      options: [
        Option.new(
          id: "snap",
          label: "I get short and reactive with people I love.",
          signals: {
            "weaknesses" => { "reactivity" => 1.0 }
          }
        ),
        Option.new(
          id: "withdraw",
          label: "I quietly pull away and disappear.",
          signals: {
            "weaknesses" => { "withdrawal" => 1.0 }
          }
        ),
        Option.new(
          id: "overcommit",
          label: "I try to fix everything at once and burn the last reserves.",
          signals: {
            "weaknesses" => { "overcommitting" => 1.0 },
            "fears" => { "letting_others_down" => 0.6 }
          }
        ),
        Option.new(
          id: "numb",
          label: "I numb out — phone, food, scrolling, anything that's not the thing.",
          signals: {
            "weaknesses" => { "avoidance" => 1.0 }
          }
        )
      ],
      tags: [ "self_knowledge" ]
    ),

    Dilemma.new(
      id: "weaknesses_criticism",
      category: "weaknesses",
      title: "Criticism that lands hard",
      scenario: "Someone you respect gives you criticism in front of others. Some of it is fair, some of it isn't.",
      short_prompt: "What's your most honest first reaction?",
      options: [
        Option.new(
          id: "defend",
          label: "Defend on the spot — the unfair part can't stand.",
          signals: {
            "weaknesses" => { "defensiveness" => 1.0 }
          }
        ),
        Option.new(
          id: "shrink",
          label: "Go quiet and replay it for days afterward.",
          signals: {
            "weaknesses" => { "rumination" => 1.0 },
            "fears" => { "judgement" => 0.5 }
          }
        ),
        Option.new(
          id: "accept",
          label: "Take it cleanly in the room and sort the fair from the unfair later.",
          signals: {
            "strengths" => { "non_defensiveness" => 1.0, "self_regulation" => 0.6 }
          }
        )
      ],
      tags: [ "self_knowledge" ]
    )
  ].freeze

  DILEMMAS_BY_ID = DILEMMAS.index_by(&:id).freeze

  module_function

  def find(id)
    DILEMMAS_BY_ID[id.to_s]
  end

  def category_payload(dilemma)
    return nil unless dilemma

    {
      kind: "persona_dilemma",
      dilemma_id: dilemma.id,
      category: dilemma.category,
      label: category_label(dilemma.category),
      title: dilemma.title,
      scenario: dilemma.scenario,
      short_prompt: dilemma.short_prompt,
      options: dilemma.options.map { |opt| { id: opt.id, label: opt.label } },
      multi_select: false,
      allow_freeform: true,
      allow_skip: true
    }
  end

  def category_label(category)
    case category.to_s
    when "values" then "Quick scenario · Values"
    when "priorities" then "Quick scenario · Priorities"
    when "beliefs" then "Quick scenario · Beliefs"
    when "fears" then "Quick scenario · Fears"
    when "strengths" then "Quick scenario · Strengths"
    when "weaknesses" then "Quick scenario · Weaknesses"
    when "preferences" then "Quick scenario · Preferences"
    else "Quick scenario"
    end
  end

  def categories
    CATEGORIES
  end
end
