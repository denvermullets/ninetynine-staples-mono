source "https://rubygems.org"

gem "bcrypt", "~> 3.1.22"
gem "bootsnap", require: false
gem 'dotenv-rails'
gem "httparty"
gem "importmap-rails"
gem "json", "<= 3.0.2"
gem "mission_control-jobs"
gem "pagy"
gem "pg", "~> 1.7.0"
gem "pry"
gem "puma", ">= 8.0.2"
gem "rack-attack"
gem "rails", "~> 8.1.4"
gem "solid_cable"
gem "solid_queue", "~> 1.7.0"
gem "sprockets-rails"
gem "stimulus-rails"
gem "tailwindcss-rails", "~> 4.6.0"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "capybara"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem 'factory_bot_rails'
  gem 'faker'
  # validates /api/v1 responses against spec/support/schemas
  gem 'json_schemer', '~> 2.5'
  gem "rspec-rails", "~> 8.0.4"
  gem "rubocop"
  gem "selenium-webdriver"
end

group :development do
  gem "web-console"
end
