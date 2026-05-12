require "test_helper"

class PersonaDilemmaServiceTest < ActiveSupport::TestCase
  setup do
    @user = create_user(app_mode: :life)
    @session = @user.coach_sessions.create!(phase: :pre_round, status: :active)
  end

  test "next_dilemma returns a dilemma when none have been answered" do
    service = PersonaDilemmaService.new(user: @user, coach_session: @session)
    refute_nil service.next_dilemma
  end

  test "next_dilemma skips already-answered ones" do
    service = PersonaDilemmaService.new(user: @user, coach_session: @session)
    first = service.next_dilemma
    service.record_answer!(first.id, option_id: first.options.first.id)

    next_one = PersonaDilemmaService.new(user: @user.reload, coach_session: @session).next_dilemma
    refute_equal first.id, next_one.id
  end

  test "record_answer! accumulates trait signals on coach profile" do
    dilemma = PersonaDilemmaBank::DILEMMAS.first
    chosen = dilemma.options.first

    service = PersonaDilemmaService.new(user: @user, coach_session: @session)
    service.record_answer!(dilemma.id, option_id: chosen.id)

    signals = @user.reload.coach_profile.profile_data.fetch("persona_signals")
    chosen.signals.each do |category, traits|
      traits.each do |trait, weight|
        assert_in_delta weight.to_f, signals.dig(category, trait).to_f, 0.001
      end
    end
  end

  test "two answers of the same trait stack additively" do
    dilemma = PersonaDilemmaBank::DILEMMAS.find { |d| d.id == "values_quick_honesty_vs_kindness" }
    honesty = dilemma.options.find { |o| o.id == "honesty" }

    service = PersonaDilemmaService.new(user: @user, coach_session: @session)
    service.record_answer!(dilemma.id, option_id: honesty.id)

    fresh_user = User.find(@user.id)
    second = PersonaDilemmaService.new(user: fresh_user, coach_session: @session)
    second.record_answer!(dilemma.id, option_id: honesty.id)

    weight = User.find(@user.id).coach_profile.profile_data.dig("persona_signals", "values", "honesty").to_f
    assert_in_delta 2.0, weight, 0.001
  end

  test "trait_rankings returns descending traits within a category" do
    service = PersonaDilemmaService.new(user: @user, coach_session: @session)
    quick = PersonaDilemmaBank::DILEMMAS.find { |d| d.id == "values_quick_honesty_vs_kindness" }
    service.record_answer!(quick.id, option_id: "honesty")
    service.record_answer!(quick.id, option_id: "honesty")

    fresh = PersonaDilemmaService.new(user: @user.reload, coach_session: @session)
    fresh.record_answer!(quick.id, option_id: "kindness")

    rankings = PersonaDilemmaService.new(user: @user.reload, coach_session: @session).trait_rankings("values")
    assert_equal "honesty", rankings.first.first
  end

  test "acknowledgement_for surfaces a humanized phrase from top traits" do
    dilemma = PersonaDilemmaBank::DILEMMAS.first
    chosen = dilemma.options.first

    service = PersonaDilemmaService.new(user: @user, coach_session: @session)
    ack = service.acknowledgement_for(dilemma: dilemma, option: chosen)

    assert ack.is_a?(String)
    assert ack.strip.length.positive?
  end

  test "skip is recorded in history without applying signals" do
    dilemma = PersonaDilemmaBank::DILEMMAS.first

    service = PersonaDilemmaService.new(user: @user, coach_session: @session)
    service.record_skip!(dilemma.id)

    profile = @user.reload.coach_profile.profile_data
    assert_nil profile["persona_signals"]
    assert(profile.fetch("persona_dilemma_history").any? { |entry| entry["id"] == dilemma.id && entry["skipped_at"].present? })
  end

  test "next_dilemma prefers under-explored categories" do
    service = PersonaDilemmaService.new(user: @user, coach_session: @session)

    # Answer every "values" dilemma so that category becomes the most-touched.
    PersonaDilemmaBank::DILEMMAS.select { |d| d.category == "values" }.each do |d|
      service.record_answer!(d.id, option_id: d.options.first.id)
    end

    next_dilemma = PersonaDilemmaService.new(user: @user.reload, coach_session: @session).next_dilemma
    refute_equal "values", next_dilemma.category
  end
end
