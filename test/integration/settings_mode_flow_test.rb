require "test_helper"

class SettingsModeFlowTest < ActionDispatch::IntegrationTest
  test "user can switch from golf mode to life mode in settings" do
    user = create_user(app_mode: :golf)

    sign_in_as(user)

    get settings_path
    assert_response :success
    assert_select "nav span", text: "Saved", count: 1

    patch settings_path, params: { user: { app_mode: "life" } }
    assert_redirected_to settings_path

    follow_redirect!
    assert_response :success
    assert user.reload.life?
    assert_select "nav span", text: "Self", count: 1
  end
end
