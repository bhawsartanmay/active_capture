# This module provides functionality for storing and retrieving JSON-based capture data
# associated with specific records. It includes methods for saving captures, loading captures,
# and flushing (deleting) files in a specific directory.

require 'json'
require 'fileutils'
require 'pathname'

module Support
  class CaptureStorage
    # Constants for directory and filename constraints
    CAPTURE_DIR = 'captures'.freeze
    MAX_FILENAME_LENGTH = 100
    VALID_FILENAME_REGEX = /\A[a-zA-Z0-9\-_\.]+\z/

    class << self
      # Saves capture data to a JSON file in a structured directory.
      # @param record [Object] The record object (must respond to :class and :id).
      # @param capture_data [Hash] The data to be saved.
      # @param name [String, nil] Optional custom filename.
      # @return [Hash] Result of the operation with success status and file path or error message.
      def save_capture(record, capture_data, name = nil)
        validate_record(record) # Ensure the record is valid
        validate_capture_data(capture_data) # Ensure the capture data is valid
        
        file_name = generate_filename(record, name) # Generate a valid filename
        dir_path = create_capture_directory(record) # Create the directory for the capture
        file_path = File.join(dir_path, file_name) # Full path to the capture file

        write_capture_file(file_path, capture_data) # Write the capture data to the file
        
        { success: true, file_path: file_path }
      rescue => e
        { success: false, error: e.message }
      end

      # Loads capture data from a JSON file.
      # @param capture_file [String] Path to the capture file.
      # @return [Hash] Parsed JSON data from the file.
      # @raise [StorageError] If the file cannot be loaded or parsed.
      def load_capture(capture_file)
        validate_file_path(capture_file) # Ensure the file path is valid
        
        file_content = read_file_safely(capture_file) # Read the file content
        parsed_data = JSON.parse(file_content) # Parse the JSON content
        
        validate_parsed_data(parsed_data) # Ensure the parsed data is valid
        
        parsed_data
      rescue => e
        raise StorageError, "Failed to load capture: #{e.message}"
      end

      # Deletes all files in a specified directory under the capture directory.
      # @param directory [String] Subdirectory name under the capture directory.
      def flush(directory)
        begin
          dir_path = File.join(CAPTURE_DIR, directory) # Full path to the directory
      
          unless Dir.exist?(dir_path)
            raise StandardError, "Directory '#{dir_path}' does not exist."
          end
      
          files = Dir.glob("#{dir_path}/*") # Get all files in the directory
          
          if files.empty?
            puts "No files found in #{dir_path} to delete."
            return
          end
      
          files.each do |file|
            if File.file?(file)
              begin
                File.delete(file) # Delete each file
              rescue Errno::EACCES
                puts "Permission denied when deleting file: #{file}"
              rescue StandardError => e
                puts "Failed to delete file: #{file}. Error: #{e.message}"
              end
            end
          end
      
          puts "Flushed all files in #{dir_path} successfully."
      
        rescue StandardError => e
          puts "An error occurred during flush operation: #{e.message}"
        end
      end

      private

      # Validates that the record has the required attributes.
      def validate_record(record)
        unless record.respond_to?(:class) && record.respond_to?(:id)
          raise ArgumentError, "Invalid record: must respond to :class and :id"
        end

        if record.id.nil?
          raise ArgumentError, "Cannot capture unsaved record (ID is nil)"
        end
      end

      # Validates the structure of the capture data.
      def validate_capture_data(data)
        unless data.is_a?(Hash)
          raise ArgumentError, "Capture data must be a Hash"
        end

        required_keys = [:model, :record_id, :attributes]
        missing_keys = required_keys.reject { |k| data.key?(k) }
        unless missing_keys.empty?
          raise ArgumentError, "Missing required keys in capture data: #{missing_keys.join(', ')}"
        end
      end

      # Generates a valid filename for the capture file.
      def generate_filename(record, custom_name)
        model_name = record.class.name.downcase.gsub(/[^a-z0-9]/, '_')
        record_id = record.id.to_s
        timestamp = Time.now.strftime('%Y%m%d%H%M%S')

        if custom_name
          validate_filename(custom_name)
          base_name = custom_name.gsub(/\s+/, '_')[0..MAX_FILENAME_LENGTH]
          "#{base_name}.json"
        else
          "#{model_name}_#{record_id}_#{timestamp}.json"
        end
      end

      # Validates the custom filename.
      def validate_filename(name)
        if name.empty?
          raise ArgumentError, "Filename cannot be empty"
        end

        if name.length > MAX_FILENAME_LENGTH
          raise ArgumentError, "Filename too long (max #{MAX_FILENAME_LENGTH} chars)"
        end

        unless name.match(VALID_FILENAME_REGEX)
          raise ArgumentError, "Filename contains invalid characters"
        end
      end

      # Creates the directory for storing capture files.
      def create_capture_directory(record)
        model_name = record.class.name.downcase.gsub(/[^a-z0-9]/, '_')
        dir_path = File.join(CAPTURE_DIR, model_name)

        begin
          FileUtils.mkdir_p(dir_path) # Create the directory if it doesn't exist
        rescue SystemCallError => e
          raise StorageError, "Failed to create directory '#{dir_path}': #{e.message}"
        end

        dir_path
      end

      # Writes the capture data to a file safely.
      def write_capture_file(file_path, data)
        begin
          temp_path = "#{file_path}.tmp"
          File.write(temp_path, JSON.pretty_generate(data)) # Write to a temporary file
          File.rename(temp_path, file_path) # Rename to the final file
        rescue SystemCallError => e
          File.delete(temp_path) if File.exist?(temp_path)
          raise StorageError, "Failed to write capture file '#{file_path}': #{e.message}"
        end
      end

      # Validates the file path for loading captures.
      def validate_file_path(file_path)
        unless File.exist?(file_path)
          raise StorageError, "File does not exist: #{file_path}"
        end

        unless File.readable?(file_path)
          raise StorageError, "No read permission for file: #{file_path}"
        end

        if File.directory?(file_path)
          raise StorageError, "Path is a directory, not a file: #{file_path}"
        end
      end

      # Reads the file content safely.
      def read_file_safely(file_path)
        File.read(file_path)
      rescue SystemCallError => e
        raise StorageError, "Failed to read file '#{file_path}': #{e.message}"
      end

      # Validates the parsed JSON data structure.
      def validate_parsed_data(data)
        unless data.is_a?(Hash)
          raise StorageError, "Invalid capture format: expected JSON object"
        end

        required_keys = ['model', 'record_id', 'attributes']
        missing_keys = required_keys.reject { |k| data.key?(k) }
        unless missing_keys.empty?
          raise StorageError, "Invalid capture data: missing keys #{missing_keys.join(', ')}"
        end
      end
    end

    # Custom error class for storage-related errors.
    class StorageError < StandardError; end
  end
end
