require "test_helper"

class LearningGraphSerializerTest < ActiveSupport::TestCase
  test "serializes nodes with hierarchy and link edges" do
    user = create_user(app_mode: :life)
    rome = create_learning_node(user: user, title: "Ancient Rome")
    senate = create_learning_node(user: user, title: "Senate", parent: rome)
    other = create_learning_node(user: user, title: "Roman Law")
    LearningNodeLink.create!(from_node: rome, to_node: other, relation_kind: :related)

    payload = LearningGraphSerializer.new(user: user).call

    assert_equal 3, payload[:nodes].size
    assert payload[:nodes].all? { |n| n.key?(:root_id) }

    senate_node = payload[:nodes].find { |n| n[:id] == senate.id }
    assert_equal rome.id, senate_node[:root_id]
    refute senate_node[:is_root]

    rome_node = payload[:nodes].find { |n| n[:id] == rome.id }
    assert rome_node[:is_root]
    assert_equal rome.id, rome_node[:root_id]

    hierarchy_edge = payload[:edges].find { |e| e[:kind] == "hierarchy" && e[:source] == rome.id && e[:target] == senate.id }
    assert hierarchy_edge

    related_edge = payload[:edges].find { |e| e[:kind] == "related" }
    assert related_edge
    assert_equal rome.id, related_edge[:source]
    assert_equal other.id, related_edge[:target]
  end

  test "scopes nodes to current user" do
    user = create_user(app_mode: :life)
    other = create_user(app_mode: :life)
    create_learning_node(user: user, title: "Mine")
    create_learning_node(user: other, title: "Theirs")

    payload = LearningGraphSerializer.new(user: user).call

    titles = payload[:nodes].map { |n| n[:title] }
    assert_includes titles, "Mine"
    refute_includes titles, "Theirs"
  end
end
