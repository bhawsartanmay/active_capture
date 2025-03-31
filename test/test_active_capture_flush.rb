require 'minitest/autorun'
require 'fileutils'
require_relative '../lib/active_capture'

# Test suite for the ActiveCapture.flush method
class ActiveCaptureFlushTest < Minitest::Test
  # Directory where test captures will be stored
  CAPTURES_DIR = 'captures'.freeze

  # Setup method to prepare the test environment
  def setup
    # Create the captures directory
    FileUtils.mkdir_p(CAPTURES_DIR)
    # Create a user subdirectory
    @user_dir = File.join(CAPTURES_DIR, 'user')
    FileUtils.mkdir_p(@user_dir)
    # Add test files to the user directory
    File.write(File.join(@user_dir, 'test1.json'), '{}')
    File.write(File.join(@user_dir, 'test2.json'), '{}')
  end

  # Teardown method to clean up after tests
  def teardown
    # Remove the captures directory and its contents
    FileUtils.rm_rf(CAPTURES_DIR)
  end

  # Test flushing a valid directory with files
  def test_flush_valid_directory
    # Ensure the user directory exists and contains files
    assert Dir.exist?(@user_dir)
    assert_equal 2, Dir.glob(File.join(@user_dir, '*')).size

    # Call the flush method
    ActiveCapture.flush('user')

    # Verify the directory is empty after flushing
    assert_empty Dir.glob(File.join(@user_dir, '*'))
    puts "test_flush_valid_directory passed"
  end

  # Test flushing a non-existent directory
  def test_flush_non_existent_directory
    # Capture the output of the flush method
    output = capture_io do
      ActiveCapture.flush('non_existent_dir')
    end
    # Verify the appropriate error message is displayed
    assert_match /Directory 'captures\/non_existent_dir' does not exist./, output[0]
    puts "test_flush_non_existent_directory passed"
  end

  # Test flushing an empty directory
  def test_flush_empty_directory
    # Remove and recreate the user directory to ensure it's empty
    FileUtils.rm_rf(@user_dir)
    FileUtils.mkdir_p(@user_dir)
    assert_empty Dir.glob(File.join(@user_dir, '*'))

    # Capture the output of the flush method
    output = capture_io do
      ActiveCapture.flush('user')
    end
    # Verify the appropriate message is displayed for an empty directory
    assert_match /No files found in captures\/user to delete./, output[0]
    puts "test_flush_empty_directory passed"
  end

  # Test flushing a directory with a file that has restricted permissions
  def test_flush_with_permission_error
    # Skip this test unless run with restricted permissions
    skip "Run this test with restricted permissions to verify behavior."

    # Create a protected file with no permissions
    protected_file = File.join(@user_dir, 'protected.json')
    File.write(protected_file, '{}')
    FileUtils.chmod(0o000, protected_file)

    # Capture the output of the flush method
    output = capture_io do
      ActiveCapture.flush('user')
    end
    # Verify the appropriate error message is displayed for permission issues
    assert_match /Permission denied when deleting file: captures\/user\/protected.json/, output[0]

    # Reset permissions for cleanup
    FileUtils.chmod(0o644, protected_file)
    puts "test_flush_with_permission_error passed"
  end
end
