require 'active_capture/version'
require_relative 'active_capture/capture_storage'
require 'json'
require 'active_record'

module ActiveCapture
  class Capture
    def self.take(record, associations: [], name: nil)
      validate_record(record)

      capture_data = {
        model: record.class.name,
        record_id: record.id,
        attributes: record.attributes,
        associations: capture_associations(record, associations)
      }

      begin
        CaptureStorage.save_capture(record, capture_data, name)
      rescue StandardError => e
        raise "Failed to save capture: #{e.message}"
      end
    end

    def self.restore(record, capture_file, merge: false)
      captured_records = CaptureStorage.load_capture(capture_file)
      validate_capture(record, captured_records)

      ActiveRecord::Base.transaction do
        begin
          record.update!(captured_records['attributes'])
          restore_associations(record, captured_records['associations'], merge: merge)
        rescue StandardError => e
          raise "Failed to restore record: #{e.message}"
        end
      end
    end

    private

    def self.validate_record(record)
      unless record.is_a?(ActiveRecord::Base)
        raise ArgumentError, 'Record must be an ActiveRecord::Base instance'
      end
    end

    def self.validate_capture(record, captured_records)
      unless captured_records['record_id'] == record.id
        raise ArgumentError, 'Capture file does not match the given record'
      end
    end

    def self.capture_associations(record, associations)
      associations.each_with_object({}) do |association, association_data|
        association_name, nested_associations = parse_association(association)

        next unless record.respond_to?(association_name)

        begin
          related_records = record.send(association_name)
          association_data[association_name] = capture_related_records(related_records, nested_associations)
        rescue StandardError => e
          raise "Failed to capture association #{association_name}: #{e.message}"
        end
      end
    end

    def self.capture_related_records(related_records, nested_associations)
      if related_records.is_a?(ActiveRecord::Base)
        {
          attributes: related_records.attributes,
          associations: capture_associations(related_records, nested_associations)
        }
      elsif related_records.respond_to?(:map)
        related_records.map do |related_record|
          {
            attributes: related_record.attributes,
            associations: capture_associations(related_record, nested_associations)
          }
        end
      end
    end

    def self.parse_association(association)
      if association.is_a?(Hash)
        [association.keys.first, association.values.flatten]
      else
        [association, []]
      end
    end

    def self.restore_associations(record, associations_data, merge: false)
      associations_data.each do |association_name, related_data|
        if related_data.is_a?(Array)
          restore_collection_association(record, association_name, related_data, merge)
        else
          restore_single_association(record, association_name, related_data, merge)
        end
      end
    end

    def self.restore_collection_association(record, association_name, related_data, merge)
      associated_class = record.class.reflect_on_association(association_name).klass
      existing_records = record.send(association_name)

      related_data.each do |related_record_data|
        if merge && related_record_data['attributes']['id']
          existing_record = existing_records.find_by(id: related_record_data['attributes']['id'])
          if existing_record
            update_and_restore(existing_record, related_record_data, merge)
            next
          end
        end
        create_and_restore(associated_class, related_record_data, record, association_name)
      end
    end

    def self.restore_single_association(record, association_name, related_data, merge)
      associated_class = record.class.reflect_on_association(association_name).klass

      if merge && related_data['attributes']['id']
        existing_record = record.send(association_name)
        if existing_record&.id == related_data['attributes']['id']
          update_and_restore(existing_record, related_data, merge)
          return
        end
      end

      new_record = create_and_restore(associated_class, related_data)
      record.update!(association_name => new_record)
    end

    def self.update_and_restore(record, related_data, merge)
      record.update!(related_data['attributes'])
      restore_associations(record, related_data['associations'], merge: merge)
    end

    def self.create_and_restore(associated_class, related_data, parent_record = nil, association_name = nil)
      new_record = associated_class.create!(related_data['attributes'])
      restore_associations(new_record, related_data['associations'], merge: false)
      parent_record&.update!(association_name => new_record) if association_name
      new_record
    end
  end
end
