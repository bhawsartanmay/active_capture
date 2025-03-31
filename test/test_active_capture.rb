require 'test_helper'
require 'minitest/autorun'

class ActiveCaptureTest < Minitest::Test
  def setup
    @user = User.create!(name: "John Doe", email: "john@example.com")
    @post = @user.posts.create!(title: "First Post", content: "This is my first post.")
    @comment1 = @post.comments.create!(content: "Great post!")
    @comment2 = @post.comments.create!(content: "Thanks for sharing.")
  end

  def test_capture_with_associations
    ActiveCapture::Capture.take(@user, associations: [:posts, { posts: :comments }])

    capture_files = Dir["captures/user/*.json"]
    assert !capture_files.empty?, "capture file should be created"

    capture_content = JSON.parse(File.read(capture_files.last))
    assert_equal 1, capture_content["associations"]["posts"].size
    assert_equal 2, capture_content["associations"]["posts"].first["associations"]["comments"].size
  end

  def test_restore_with_merge
    ActiveCapture::Capture.take(@user, associations: [:posts, { posts: :comments }])
    capture_file = Dir["captures/user/*.json"].last
    @post.update(title: "updated title")
    new_comment = @post.comments.create!(content: "Another comment")
    ActiveCapture::Capture.restore(@user, capture_file, merge: true)

    @user.reload
    @post.reload

    assert_equal "John Doe", @user.name
    assert_equal "First Post", @post.title
    assert_equal 3, @post.comments.count
    assert @post.comments.exists?(new_comment.id), "New comment should still exist after merge"
  end
end
