require "test_helper"

class PersonaDilemmaBankTest < ActiveSupport::TestCase
  test "dilemmas have unique ids" do
    ids = PersonaDilemmaBank::DILEMMAS.map(&:id)
    assert_equal ids.uniq.length, ids.length, "duplicate dilemma ids: #{ids.tally.select { |_, c| c > 1 }.keys}"
  end

  test "every dilemma has a recognized category" do
    PersonaDilemmaBank::DILEMMAS.each do |dilemma|
      assert_includes PersonaDilemmaBank::CATEGORIES, dilemma.category,
        "dilemma #{dilemma.id} has unknown category #{dilemma.category}"
    end
  end

  test "every dilemma has 2 to 4 well-formed options" do
    PersonaDilemmaBank::DILEMMAS.each do |dilemma|
      assert_includes 2..4, dilemma.options.length, "dilemma #{dilemma.id} should have 2-4 options"
      option_ids = dilemma.options.map(&:id)
      assert_equal option_ids.uniq.length, option_ids.length, "dilemma #{dilemma.id} has duplicate option ids"
      dilemma.options.each do |option|
        assert option.label.is_a?(String) && option.label.strip.length.positive?
        assert option.signals.is_a?(Hash) && option.signals.any?,
          "option #{dilemma.id}/#{option.id} must include trait signals"
      end
    end
  end

  test "covers all required categories at least once" do
    seen = PersonaDilemmaBank::DILEMMAS.map(&:category).uniq
    %w[values priorities beliefs fears strengths weaknesses].each do |required|
      assert_includes seen, required, "missing dilemma category: #{required}"
    end
  end

  test "category_payload returns a UI-ready hash" do
    dilemma = PersonaDilemmaBank::DILEMMAS.first
    payload = PersonaDilemmaBank.category_payload(dilemma)

    assert_equal "persona_dilemma", payload[:kind]
    assert_equal dilemma.id, payload[:dilemma_id]
    assert_equal dilemma.category, payload[:category]
    refute payload[:multi_select]
    assert payload[:allow_freeform]
    assert payload[:options].all? { |opt| opt[:id].present? && opt[:label].present? }
  end
end
