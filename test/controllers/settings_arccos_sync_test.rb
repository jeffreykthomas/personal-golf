require "test_helper"

class SettingsArccosSyncTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    sign_in_as(@user)
  end

  test "shows arccos sync section with status" do
    get settings_path
    assert_response :success
    assert_match "Arccos sync", response.body
    assert_match "Sync now", response.body
  end

  test "trigger_arccos_sync posts to bridge and transitions status to running" do
    stub_bridge = Minitest::Mock.new
    stub_bridge.expect :trigger_sync, { "status" => "accepted" }, [], force: true

    ArccosBridgeClient.stub :new, ->(user:) { assert_equal @user.id, user.id; stub_bridge } do
      post trigger_arccos_sync_settings_path
    end

    assert_redirected_to settings_path
    assert_match(/sync started/i, flash[:notice])
    assert_equal "running", ArccosProfile.for(@user).last_sync_status
    stub_bridge.verify
  end

  test "trigger_arccos_sync short-circuits if already running" do
    ArccosProfile.for(@user).tap do |p|
      p.save!
      p.update!(last_sync_status: "running")
    end

    ArccosBridgeClient.stub :new, ->(*) { raise "should not be called" } do
      post trigger_arccos_sync_settings_path
    end

    assert_redirected_to settings_path
    assert_match(/already running/i, flash[:notice])
  end

  test "trigger_arccos_sync surfaces bridge errors as flash alert" do
    failing = Object.new
    def failing.trigger_sync(force:)
      raise ArccosBridgeClient::BridgeUnavailableError, "bridge_unreachable:ECONNREFUSED"
    end

    ArccosBridgeClient.stub :new, ->(*) { failing } do
      post trigger_arccos_sync_settings_path
    end

    assert_redirected_to settings_path
    assert_match(/Couldn.t reach the agent bridge/i, flash[:alert])
  end
end
