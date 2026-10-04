# A game client's login. The raw token ("mtg_" + 43 url-safe chars, prefixed so a leaked one is
# greppable) goes back to the client once from issue! and is never stored - lookups go by digest
class ApiToken < ApplicationRecord
  PREFIX = 'mtg_'.freeze
  LIFETIME = 90.days
  # last_used_at is bumped at most this often, so a busy client isn't a write on every request
  TOUCH_INTERVAL = 5.minutes

  belongs_to :user

  validates :name, presence: true, length: { maximum: 100 }
  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil).where('expires_at IS NULL OR expires_at > ?', Time.current) }

  # returns [record, raw_token]
  def self.issue!(user, name:)
    raw_token = "#{PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    record = create!(user: user, name: name, token_digest: digest(raw_token), expires_at: LIFETIME.from_now)
    [record, raw_token]
  end

  def self.digest(raw_token)
    OpenSSL::Digest::SHA256.hexdigest(raw_token)
  end

  def self.find_active(raw_token)
    return if raw_token.blank?

    active.find_by(token_digest: digest(raw_token))
  end

  # call on a scope, e.g. user.api_tokens.revoke_all! - logs the user out of every game client
  def self.revoke_all!
    now = Time.current
    active.update_all(revoked_at: now, updated_at: now)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  # sliding expiry: a client that keeps playing never has to log in again, one left alone for
  # LIFETIME does
  def touch_last_used!
    return if last_used_at && last_used_at > TOUCH_INTERVAL.ago

    now = Time.current
    update_columns(last_used_at: now, expires_at: expires_at && (now + LIFETIME), updated_at: now)
  end
end
