require "test_helper"

class LearningModeFlowTest < ActionDispatch::IntegrationTest
  test "life mode nav shows learning instead of courses" do
    user = create_user(app_mode: :life)

    sign_in_as(user)

    get learning_path
    assert_response :success
    assert_select "nav span", text: "Learning", count: 1
    assert_select "nav span", text: "Courses", count: 0
    assert_select "h1", text: "Learning"
    assert_select "turbo-cable-stream-source", minimum: 1
  end

  test "creating a topic queues source discovery" do
    user = create_user(app_mode: :life)

    sign_in_as(user)

    assert_enqueued_with(job: LearningSourceDiscoveryJob) do
      assert_difference -> { user.learning_nodes.count }, +1 do
        post learning_nodes_path, params: {
          learning_node: {
            title: "Ancient Rome"
          }
        }
      end
    end

    node = user.learning_nodes.find_by!(title: "Ancient Rome")
    assert_redirected_to learning_path(node_id: node.id)
    assert node.pending_research?
  end

  test "vault tree expands only the selected branch" do
    user = create_user(app_mode: :life)
    root = create_learning_node(user: user, title: "Quantum Physics")
    child = create_learning_node(user: user, parent: root, title: "Measurement Problem")
    grandchild = create_learning_node(user: user, parent: child, title: "Bohmian Mechanics")

    sign_in_as(user)

    get learning_path
    assert_response :success
    assert_select "aside ul.ml-4", count: 0

    get learning_path(node_id: root.id)
    assert_response :success
    assert_select "aside ul.ml-4 a[href='#{learning_path(node_id: child.id)}']", count: 1
    assert_select "aside ul.ml-4 a[href='#{learning_path(node_id: grandchild.id)}']", count: 0

    get learning_path(node_id: child.id)
    assert_response :success
    assert_select "aside ul.ml-4 a[href='#{learning_path(node_id: grandchild.id)}']", count: 1
  end
end
