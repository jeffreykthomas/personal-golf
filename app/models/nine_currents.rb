module NineCurrents
  Definition = Data.define(
    :name,
    :summary,
    :description,
    :enneagram_inspiration,
    :growth_question
  )

  DEFINITIONS = [
    Definition.new(
      name: "Drive",
      summary: "Achievement, momentum, visible progress, and the need to turn effort into results.",
      description: "Tracks ambition, performance identity, goal pursuit, image pressure, and the energy that moves a person toward outcomes.",
      enneagram_inspiration: "Loosely echoes Type 3, without assigning a type.",
      growth_question: "Where is striving serving the person, and where is it narrowing them?"
    ),
    Definition.new(
      name: "Stability",
      summary: "Security, preparedness, loyalty, trust, and the need for reliable ground.",
      description: "Tracks risk scanning, planning, anxiety, allegiance, skepticism, and the search for structures that hold under pressure.",
      enneagram_inspiration: "Loosely echoes Type 6, without assigning a type.",
      growth_question: "What creates steadiness, and what turns caution into confinement?"
    ),
    Definition.new(
      name: "Connection",
      summary: "Care, belonging, relational attunement, helpfulness, and the need to matter to others.",
      description: "Tracks warmth, caretaking, approval-seeking, reciprocity, family/social bonds, and how relationships shape choice.",
      enneagram_inspiration: "Loosely echoes Type 2, without assigning a type.",
      growth_question: "Where does connection nourish, and where does it blur self-possession?"
    ),
    Definition.new(
      name: "Agency",
      summary: "Power, boundaries, directness, autonomy, and the need to act from one's own authority.",
      description: "Tracks decisiveness, control, resistance to weakness, conflict style, protective force, and self-trust in action.",
      enneagram_inspiration: "Loosely echoes Type 8, without assigning a type.",
      growth_question: "Where is force needed, and where would openness be stronger?"
    ),
    Definition.new(
      name: "Reflection",
      summary: "Observation, analysis, inner privacy, knowledge, and the need to understand before acting.",
      description: "Tracks intellectualization, pattern recognition, information hunger, solitude, restraint, and clarity-seeking.",
      enneagram_inspiration: "Loosely echoes Type 5, without assigning a type.",
      growth_question: "Where does analysis clarify, and where does it postpone contact?"
    ),
    Definition.new(
      name: "Expression",
      summary: "Emotional truth, distinctiveness, beauty, longing, and the need for authentic self-expression.",
      description: "Tracks identity texture, symbolism, grief, aesthetic sensitivity, emotional intensity, and the wish to be truly seen.",
      enneagram_inspiration: "Loosely echoes Type 4, without assigning a type.",
      growth_question: "What truth wants expression, and what story is intensifying suffering?"
    ),
    Definition.new(
      name: "Resilience",
      summary: "Integrity, standards, discipline, repair, and the need to become better without becoming harsh.",
      description: "Tracks conscience, self-criticism, improvement loops, rule-making, ideals, anger, and recovery after falling short.",
      enneagram_inspiration: "Loosely echoes Type 1, without assigning a type.",
      growth_question: "Where are standards helping, and where are they becoming punishment?"
    ),
    Definition.new(
      name: "Curiosity",
      summary: "Possibility, exploration, reframing, appetite for options, and the need to keep life open.",
      description: "Tracks novelty, mental range, optimism, escape routes, experimentation, and the instinct to expand beyond constraint.",
      enneagram_inspiration: "Loosely echoes Type 7, without assigning a type.",
      growth_question: "What possibility is life-giving, and what possibility is avoidance?"
    ),
    Definition.new(
      name: "Integration",
      summary: "Peace, wholeness, acceptance, mediation, and the need for inner and outer coherence.",
      description: "Tracks harmony, diffusion, patience, spiritual synthesis, conflict avoidance, and the work of bringing divided parts together.",
      enneagram_inspiration: "Loosely echoes Type 9, without assigning a type.",
      growth_question: "What wants to be reconciled, and what is being numbed or deferred?"
    )
  ].freeze

  module_function

  def names
    DEFINITIONS.map(&:name)
  end

  def definition_for(name)
    DEFINITIONS.find { |definition| definition.name == name }
  end

  def prompt_context
    DEFINITIONS.map do |definition|
      <<~TEXT.squish
        - #{definition.name}: #{definition.summary}
        #{definition.enneagram_inspiration}
        Growth question: #{definition.growth_question}
      TEXT
    end.join("\n")
  end
end
