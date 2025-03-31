require 'active_capture/version'
require_relative 'active_capture/capture_storage'
require 'json'
require 'active_record'

module ActiveCapture
  class Capture
    def self.take(record, associations: [], name: nil)
      raise ArgumentError, 'Record must be an ActiveRecord::Base instance' unless record.is_a?(ActiveRecord::Base)

      capture_data = {
        model: record.class.name,
        record_id: record.id,
        attributes: record.attributes,
        associations: capture_associations(record, associations)
      }

      CaptureStorage.save_capture(record, capture_data, name)
    end

    def self.restore(record, capture_file, merge: false)
      captured_records = CaptureStorage.load_capture(capture_file)

      raise ArgumentError, 'capture file does not match the given record' unless captured_records['record_id'] == record.id

      ActiveRecord::Base.transaction do
        record.update!(captured_records['attributes'])
        restore_associations(record, captured_records['associations'], merge: merge)
      end
    end

    private

    def self.capture_associations(record, associations)
      association_data = {}

      associations.each do |association|
        nested_associations = []

        if association.is_a?(Hash)
          association_name = association.keys.first
          nested_associations = association.values.flatten
        else
          association_name = association
        end

        if record.respond_to?(association_name)
          related_records = record.send(association_name)

          if related_records.is_a?(ActiveRecord::Base)
            association_data[association_name] = {
              attributes: related_records.attributes,
              associations: capture_associations(related_records, nested_associations)
            }
          elsif related_records.respond_to?(:map)
            association_data[association_name] = related_records.map do |related_record|
              {
                attributes: related_record.attributes,
                associations: capture_associations(related_record, nested_associations)
              }
            end
          end
        end
      end

      association_data
    end

    def self.restore_associations(record, associations_data, merge: false)
      associations_data.each do |association_name, related_data|
        if related_data.is_a?(Array)
          associated_class = record.class.reflect_on_association(association_name).klass
          existing_records = record.send(association_name)

          related_data.each do |related_record_data|
            if related_record_data['attributes']['id'] && existing_record = existing_records.find_by(id: related_record_data['attributes']['id'])
              existing_record.update!(related_record_data['attributes'])
              restore_associations(existing_record, related_record_data['associations'], merge: merge)
            else
              new_record = associated_class.create!(related_record_data['attributes'])
              restore_associations(new_record, related_record_data['associations'], merge: merge)
            end
          end
        else
          associated_class = record.class.reflect_on_association(association_name).klass
          if merge && related_data['attributes']['id']
            existing_record = record.send(association_name)

            if existing_record && existing_record.id == related_data['attributes']['id']
              existing_record.update!(related_data['attributes'])
              restore_associations(existing_record, related_data['associations'], merge: merge)
            else
              new_record = associated_class.create!(related_data['attributes'])
              record.update!(association_name => new_record)
              restore_associations(new_record, related_data['associations'], merge: merge)
            end
          else
            new_record = associated_class.create!(related_data['attributes'])
            record.update!(association_name => new_record)
            restore_associations(new_record, related_data['associations'], merge: merge)
          end
        end
      end
    end
  end
end
