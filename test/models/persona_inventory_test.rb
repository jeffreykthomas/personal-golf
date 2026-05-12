require "test_helper"

class PersonaInventoryTest < ActiveSupport::TestCase
  test "exposes a known set of slots covering values priorities preferences likes and dislikes" do
    groups = PersonaInventory::SLOTS.map(&:group).uniq
    PersonaInventory::GROUPS.each do |group|
      assert_includes groups, group, "expected at least one slot in group #{group}"
    end
  end

  test "every slot has a non-empty question and option list" do
    PersonaInventory::SLOTS.each do |slot|
      assert slot.prompt.to_s.strip.length.positive?, "slot #{slot.key} missing prompt"
      assert slot.options.any?, "slot #{slot.key} missing options"
      assert slot.options.all? { |option| option.is_a?(String) && option.strip.length.positive? }
    end
  end

  test "find returns slot by key" do
    slot = PersonaInventory.find("core_values")
    assert_equal "core_values", slot.key
    assert_nil PersonaInventory.find("does_not_exist")
  end

  test "slot_payload returns a serializable hash for the UI" do
    slot = PersonaInventory.find("core_values")
    payload = PersonaInventory.slot_payload(slot)

    assert_equal "core_values", payload[:slot]
    assert_equal slot.options, payload[:options]
    assert payload[:multi_select]
    assert payload[:allow_freeform]
    assert payload[:max_options].positive?
  end
end
