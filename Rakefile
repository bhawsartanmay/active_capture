# frozen_string_literal: true

require "bundler/gem_tasks"
# task default: %i[]

require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

task default: :test
