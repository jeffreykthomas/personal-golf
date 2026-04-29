require "test_helper"

class NineCurrentsTest < ActiveSupport::TestCase
  test "defines nine named currents with enneagram inspirations" do
    assert_equal 9, NineCurrents::DEFINITIONS.size
    assert_equal SelfUnderstandingReport::CURRENT_ORDER, NineCurrents.names

    NineCurrents::DEFINITIONS.each do |definition|
      assert definition.summary.present?
      assert definition.description.present?
      assert_match(/Type \d/, definition.enneagram_inspiration)
      assert definition.growth_question.present?
    end
  end

  test "prompt context includes each current definition" do
    prompt_context = NineCurrents.prompt_context

    NineCurrents.names.each do |name|
      assert_includes prompt_context, name
    end
  end
end
