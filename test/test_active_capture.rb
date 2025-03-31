require 'test_helper'
require 'minitest/autorun'

class ActiveCaptureTest < Minitest::Test
  # Setup method to initialize test data before each test
  def setup
    @user = User.create!(name: "John Doe", email: "john@example.com")
    @post = @user.posts.create!(title: "First Post", content: "This is my first post.")
    @comment1 = @post.comments.create!(content: "Great post!")
    @comment2 = @post.comments.create!(content: "Thanks for sharing.")
  end

  # Teardown method to clean up after each test
  def teardown
    FileUtils.rm_rf('captures/')
  end

  # Test capturing a user with associated posts and comments
  def test_capture_with_associations
    # Take a capture of the user and their associations
    ActiveCapture.take(@user, associations: [:posts, { posts: :comments }])

    # Verify that capture files are created
    capture_files = Dir["captures/user/*.json"]
    assert !capture_files.empty?, "capture file should be created"

    # Verify the content of the capture file
    capture_content = JSON.parse(File.read(capture_files.last))
    assert_equal 1, capture_content["associations"]["posts"].size
    assert_equal 2, capture_content["associations"]["posts"].first["associations"]["comments"].size
  end

  # Test restoring a user with merge functionality
  def test_restore_with_merge
    # Take a capture of the user and their associations
    ActiveCapture.take(@user, associations: [:posts, { posts: :comments }])
    capture_file = Dir["captures/user/*.json"].last

    # Modify the post and add a new comment
    @post.update(title: "updated title")
    new_comment = @post.comments.create!(content: "Another comment")

    # Restore the user from the capture file with merge enabled
    ActiveCapture.restore(@user, capture_file, merge: true)

    # Reload the user and post to verify changes
    @user.reload
    @post.reload

    # Verify that the user's name is restored
    assert_equal "John Doe", @user.name

    # Verify that the post's title is restored
    assert_equal "First Post", @post.title

    # Verify that the new comment still exists after the merge
    assert_equal 3, @post.comments.count
    assert @post.comments.exists?(new_comment.id), "New comment should still exist after merge"
  end
end
