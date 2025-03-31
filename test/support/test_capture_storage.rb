require 'test_helper'
require 'minitest/autorun'
require 'fileutils'

# Define our test classes at the top level
class TestModel; end
class NewModel; end
class ProtectedModel; end

class CaptureStorageTest < Minitest::Test
  # Simple test record class that mimics ActiveRecord::Base
  class TestRecord
    attr_reader :id

    def initialize(id, class_name)
      @id = id
      @class_name = class_name
    end

    def class
      @class_name.constantize
    end
  end

  def setup
    # Create test data directory
    @test_dir = 'test_data'
    FileUtils.mkdir_p(@test_dir)

    # Create sample capture data
    @sample_data = {
      model: 'TestModel',
      record_id: 1,
      attributes: { name: 'Test', value: 42 },
      associations: {
        comments: [
          { attributes: { id: 1, content: 'First comment' } },
          { attributes: { id: 2, content: 'Second comment' } }
        ]
      }
    }

    # Create test files
    @valid_file = "#{@test_dir}/valid.json"
    File.write(@valid_file, JSON.generate(@sample_data))

    @invalid_json_file = "#{@test_dir}/invalid.json"
    File.write(@invalid_json_file, 'not valid json')

    @empty_file = "#{@test_dir}/empty.json"
    File.write(@empty_file, '')

    # Clear captures directory before each test
    FileUtils.rm_rf(Support::CaptureStorage::CAPTURE_DIR) if File.directory?(Support::CaptureStorage::CAPTURE_DIR)
  end

  def teardown
    # Clean up test files
    FileUtils.rm_rf(@test_dir)
    FileUtils.rm_rf(Support::CaptureStorage::CAPTURE_DIR)
  end

  def test_save_capture_creates_valid_file
    test_record = TestRecord.new(1, 'TestModel')
    result = Support::CaptureStorage.save_capture(test_record, @sample_data)

    assert result[:success], "Save should succeed: #{result[:error]}"
    assert File.exist?(result[:file_path]), "File should exist at #{result[:file_path]}"

    file_content = JSON.parse(File.read(result[:file_path]))
    assert_equal 'TestModel', file_content['model']
    assert_equal 1, file_content['record_id']
  end

  def test_save_capture_with_custom_name
    test_record = TestRecord.new(1, 'TestModel')
    custom_name = 'custom_capture'
    result = Support::CaptureStorage.save_capture(test_record, @sample_data, custom_name)

    assert result[:success], "Save should succeed: #{result[:error]}"
    assert_match /#{custom_name}\.json/, result[:file_path]
    assert File.exist?(result[:file_path]), "File should exist at #{result[:file_path]}"
  end

  def test_save_capture_invalid_filename
    test_record = TestRecord.new(1, 'TestModel')
    result = Support::CaptureStorage.save_capture(test_record, @sample_data, 'invalid/name')

    refute result[:success], "Save should fail with invalid filename"
    assert_match /Filename contains invalid characters/, result[:error], "Error should mention invalid filename"
  end

  def test_load_capture_valid_file
    data = Support::CaptureStorage.load_capture(@valid_file)

    assert_equal 'TestModel', data['model']
    assert_equal 1, data['record_id']
    assert_equal 2, data['associations']['comments'].size
  end

  def test_load_capture_nonexistent_file
    assert_raises Support::CaptureStorage::StorageError do
      Support::CaptureStorage.load_capture('nonexistent.json')
    end
  end

  def test_load_capture_invalid_json
    assert_raises Support::CaptureStorage::StorageError do
      Support::CaptureStorage.load_capture(@invalid_json_file)
    end
  end

  def test_load_capture_empty_file
    assert_raises Support::CaptureStorage::StorageError do
      Support::CaptureStorage.load_capture(@empty_file)
    end
  end

  def test_load_capture_missing_required_keys
    incomplete_data = { 'some_key' => 'some_value' }
    incomplete_file = "#{@test_dir}/incomplete.json"
    File.write(incomplete_file, JSON.generate(incomplete_data))

    assert_raises Support::CaptureStorage::StorageError do
      Support::CaptureStorage.load_capture(incomplete_file)
    end
  end

  def test_atomic_write_handles_failure
    # Create a directory we can't write to
    protected_dir = "#{@test_dir}/protected"
    FileUtils.mkdir_p(protected_dir)
    FileUtils.chmod(0444, protected_dir) # read-only

    test_record = TestRecord.new(1, 'ProtectedModel')
    file_path = "#{protected_dir}/test.json"

    assert_raises Support::CaptureStorage::StorageError do
      Support::CaptureStorage.send(:write_capture_file, file_path, @sample_data)
    end

    # Verify no temp file remains
    refute File.exist?("#{file_path}.tmp")
  ensure
    FileUtils.chmod(0755, protected_dir) if File.exist?(protected_dir)
  end

  def test_directory_creation
    test_record = TestRecord.new(1, 'NewModel')
    result = Support::CaptureStorage.save_capture(test_record, @sample_data)

    assert result[:success], "Save should succeed: #{result[:error]}"
    assert File.directory?('captures/newmodel'), "Directory should be created"
  end
end
