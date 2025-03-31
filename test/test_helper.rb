# test/test_helper.rb
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)  # This line makes sure your gem's lib directory is included in the load path.
require "active_capture"
require "minitest/autorun"
require "active_record"

# Setup an in-memory SQLite database for testing
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.timestamps
  end

  create_table :posts, force: true do |t|
    t.integer :user_id
    t.string :title
    t.text :content
    t.timestamps
  end

  create_table :comments, force: true do |t|
    t.integer :post_id
    t.string :content
    t.timestamps
  end
end

class User < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :user
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

