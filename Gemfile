source "https://rubygems.org"

gem "bootsnap", require: false
gem "httparty"
gem "importmap-rails"
gem "mission_control-jobs"
gem "pagy"
gem "pg", "~> 1.5.9"
gem "pry"
gem "puma", ">= 6.5.0"
gem "rails", "~> 8.0.1"
gem "revise_auth", "~> 0.8.0"
gem "solid_queue", "~> 1.1.3"
gem "sprockets-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[windows jruby]

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end

# rubocop:disable Bundler/DuplicatedGem
group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "rspec-rails", "~> 7.1.0"
  gem "rubocop"
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem 'factory_bot_rails'
  gem 'faker'
  gem "rspec-rails", "~> 7.1.0"
  gem "selenium-webdriver"
end
# rubocop:enable Bundler/DuplicatedGem
