require "test_helper"

class TipTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @category = categories(:one)
  end

  test "should create tip with valid youtube url" do
    tip = Tip.new(
      title: "Test Tip",
      content: "This is a test tip content",
      user: @user,
      category: @category,
      youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    )
    
    assert tip.valid?
  end

  test "should not create tip with invalid youtube url" do
    tip = Tip.new(
      title: "Test Tip",
      content: "This is a test tip content",
      user: @user,
      category: @category,
      youtube_url: "https://invalid-url.com"
    )
    
    assert_not tip.valid?
    assert_includes tip.errors[:youtube_url], "is invalid"
  end

  test "should extract youtube video id correctly" do
    tip = Tip.new(youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    assert_equal "dQw4w9WgXcQ", tip.youtube_video_id
  end

  test "should extract youtube video id from youtu.be url" do
    tip = Tip.new(youtube_url: "https://youtu.be/dQw4w9WgXcQ")
    assert_equal "dQw4w9WgXcQ", tip.youtube_video_id
  end

  test "should generate correct thumbnail url" do
    tip = Tip.new(youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    expected_url = "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"
    assert_equal expected_url, tip.youtube_thumbnail_url
  end

  test "should return false for has_youtube_video? when no url" do
    tip = Tip.new
    assert_not tip.has_youtube_video?
  end

  test "should return true for has_youtube_video? when valid url" do
    tip = Tip.new(youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    assert tip.has_youtube_video?
  end
end