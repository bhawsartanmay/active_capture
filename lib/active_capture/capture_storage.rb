require 'json'
require 'fileutils'

module ActiveCapture
  class CaptureStorage
    CAPTURE_DIR = 'captures'

    def self.save_capture(record, capture_data, name = nil)
      model_name = record.class.name.downcase
      record_id = record.id
      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      file_name = name ? "#{name}.json" : "#{record_id}_#{timestamp}.json"

      dir_path = File.join(CAPTURE_DIR, model_name)
      FileUtils.mkdir_p(dir_path)

      file_path = File.join(dir_path, file_name)
      File.write(file_path, JSON.pretty_generate(capture_data))

      puts "Capture saved to #{file_path}"
    end

    def self.load_capture(capture_file)
      raise ArgumentError, "Capture file does not exist #{capture_file}" unless File.exist?(capture_file)

      JSON.parse(File.read(capture_file))
    end
  end
end
