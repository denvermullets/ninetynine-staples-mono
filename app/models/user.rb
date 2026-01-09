class User < ApplicationRecord
  has_secure_password
  has_many :collections

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :username, presence: true
  validates :password, length: { minimum: 10 }, allow_nil: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :password_reset, expires_in: 1.hour do
    password_digest&.last(10)
  end
end
