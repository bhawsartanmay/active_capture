# frozen_string_literal: true

require_relative "lib/active_capture/version"

Gem::Specification.new do |spec|
  spec.name          = "active_capture"
  spec.version       = ActiveCapture::VERSION
  spec.authors       = "Tanmay Bhawsar"
  spec.email         = "bhawsartanmay@gmail.com"
  spec.summary       = "A Ruby on Rails gem for taking and restoring captures of ActiveRecord records with nested associations."
  spec.description   = "ActiveCapture allows you to save captures of ActiveRecord records, including their nested associations, and restore them at any point. Useful for auditing, backups, and rollback functionality."
  spec.homepage      = "https://github.com/bhawsartanmay/active_capture"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir.glob("lib/**/*.rb") + Dir.glob("test/**/*")
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bhawsartanmay/active_capture"
end
