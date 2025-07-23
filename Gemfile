source "https://rubygems.org"

gem "bootsnap", require: false
gem 'dotenv-rails'
gem "httparty"
gem "importmap-rails"
gem "mission_control-jobs"
gem "pagy"
gem "pg", "~> 1.5.9"
gem "pry"
gem "puma", ">= 6.6.0"
gem "rails", "~> 8.0.2"
gem "revise_auth", "~> 0.8.0"
gem "solid_queue", "~> 1.2.1"
gem "sprockets-rails"
gem "stimulus-rails"
# sticking with this version tailwind for now since there's issues w/upgrade path
gem "tailwindcss-rails", "~> 4.2.3"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[windows jruby]

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "capybara"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem 'factory_bot_rails'
  gem 'faker'
  gem "rspec-rails", "~> 8.0.1"
  gem "rubocop"
  gem "selenium-webdriver"
  gem "web-console"
end
