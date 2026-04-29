require "test_helper"

class LearningRebalancingServiceTest < ActiveSupport::TestCase
  test "groups crowded child branches into bucket nodes" do
    user = create_user(app_mode: :life)
    node = create_learning_node(user: user, title: "Ancient Rome")
    children = %w[Monarchy Republic Empire Army Law Religion Economy]
    children.each_with_index do |title, index|
      create_learning_node(user: user, parent: node, title: title, position: index)
    end

    payload = {
      "buckets" => [
        {
          "title" => "Political Structure",
          "summary" => "Government and institutional forms.",
          "child_titles" => ["Monarchy", "Republic", "Empire", "Law"]
        },
        {
          "title" => "Social And Material Life",
          "summary" => "How Roman life functioned in practice.",
          "child_titles" => ["Army", "Religion", "Economy"]
        }
      ]
    }

    NanoclawLearningBridgeService.stub(:rebalance_node, payload) do
      assert LearningRebalancingService.new(node: node).call
    end

    political_bucket = node.reload.children.cluster.find_by!(title: "Political Structure")
    social_bucket = node.children.cluster.find_by!(title: "Social And Material Life")

    assert_equal political_bucket.id, node.user.learning_nodes.find_by!(title: "Republic").parent_id
    assert_equal social_bucket.id, node.user.learning_nodes.find_by!(title: "Economy").parent_id
    assert node.ready?
  end
end
