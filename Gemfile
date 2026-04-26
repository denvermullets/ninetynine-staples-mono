source "https://rubygems.org"

gem "bcrypt", "~> 3.1.22"
gem "bootsnap", require: false
gem 'dotenv-rails'
gem "httparty"
gem "importmap-rails"
gem "mission_control-jobs"
gem "pagy"
gem "pg", "~> 1.6.3"
gem "pry"
gem "puma", ">= 8.0.0"
gem "rack-attack"
gem "rails", "~> 8.1.3"
gem "solid_cable"
gem "solid_queue", "~> 1.4.0"
gem "sprockets-rails"
gem "stimulus-rails"
gem "tailwindcss-rails", "~> 4.4.0"
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
  gem "rspec-rails", "~> 8.0.4"
  gem "rubocop"
  gem "selenium-webdriver"
end

group :development do
  gem "web-console"
end
