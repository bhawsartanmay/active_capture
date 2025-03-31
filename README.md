# ActiveCapture

ActiveCapture is a Ruby on Rails gem that allows you to capture and restore records along with their nested associations. It supports saving data to JSON files and restoring it later, making it useful for auditing, backups, rollback functionality, or seeding data.

## Installation

Add this line to your application's Gemfile:

```ruby
 gem 'active_capture'
```

And then execute:

```sh
 $ bundle install
```

Or install it yourself as:

```sh
 $ gem install active_capture
```

## Usage

### Capture a Record Without Associations
```ruby
user = User.find(1)
ActiveCapture::Capture.take(user)
```
This will create a JSON file in the `snapshots/` directory.

### Capture a Record With Associations
```ruby
user = User.find(1)
ActiveCapture::Capture.take(user, associations: [:posts, :comments])
```
This will include all associated posts and comments of the user.

### Capture a Record With Custom Filename
```ruby
user = User.find(1)
ActiveCapture::Capture.take(user, filename: "custom_user_data.json")
```
The file will be saved as `snapshots/custom_user_data.json`.

### Restore a Record
```ruby
user = User.find(1)
ActiveCapture::Capture.restore(user, filename: "user/1_20250329013025.json")
```
This will restore the user's state from the given file.

### Restore a Record With Specific Associations
```ruby
user = User.find(1)
ActiveCapture::Capture.restore(user, associations: [:posts])
```
Only the specified associations (`posts`) will be restored.

### Usage In Rake Task
```ruby
task restore_user: :environment do
  user = User.find(1)
  ActiveCapture::Capture.restore(user, filename: "user_backup.json")
end
```

## Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/bhawsartanmay/active_capture.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

