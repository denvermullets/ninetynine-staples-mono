require 'rails_helper'

RSpec.describe ApiToken, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  describe '.issue!' do
    it 'returns the record and a prefixed raw token, storing only its digest' do
      token, raw_token = described_class.issue!(user, name: 'Laptop')

      expect(raw_token).to start_with('mtg_')
      expect(token.token_digest).to eq(OpenSSL::Digest::SHA256.hexdigest(raw_token))
      expect(token.attributes.values).not_to include(raw_token)
      expect(token.expires_at).to be_within(1.minute).of(90.days.from_now)
      expect(user.api_tokens).to contain_exactly(token)
    end

    it 'issues a different token every time' do
      raw_tokens = Array.new(3) { described_class.issue!(user, name: 'Laptop').last }

      expect(raw_tokens.uniq.size).to eq(3)
    end
  end

  describe '.find_active' do
    let!(:issued) { described_class.issue!(user, name: 'Laptop') }
    let(:token) { issued.first }
    let(:raw_token) { issued.last }

    it 'finds a live token by its raw value' do
      expect(described_class.find_active(raw_token)).to eq(token)
    end

    it 'ignores revoked, expired, unknown and blank tokens' do
      expect(described_class.find_active('mtg_nope')).to be_nil
      expect(described_class.find_active(nil)).to be_nil

      token.update!(expires_at: 1.minute.ago)
      expect(described_class.find_active(raw_token)).to be_nil

      token.update!(expires_at: nil, revoked_at: Time.current)
      expect(described_class.find_active(raw_token)).to be_nil
    end

    it 'treats a nil expires_at as never expiring' do
      token.update!(expires_at: nil)

      expect(described_class.find_active(raw_token)).to eq(token)
    end
  end

  describe '#touch_last_used!' do
    let(:token) { described_class.issue!(user, name: 'Laptop').first }

    it 'bumps last_used_at and slides expires_at forward' do
      travel_to(30.days.from_now) do
        token.touch_last_used!

        expect(token.reload.last_used_at).to be_within(1.second).of(Time.current)
        expect(token.expires_at).to be_within(1.second).of(90.days.from_now)
      end
    end

    it 'writes at most once per five minutes' do
      token.touch_last_used!
      first_use = token.reload.last_used_at

      travel(4.minutes) { token.touch_last_used! }
      expect(token.reload.last_used_at).to eq(first_use)

      travel(6.minutes) { token.touch_last_used! }
      expect(token.reload.last_used_at).to be > first_use
    end
  end

  describe '.revoke_all!' do
    it "revokes every active token in the scope and leaves other users' alone" do
      mine = Array.new(2) { described_class.issue!(user, name: 'Laptop').first }
      theirs = described_class.issue!(create(:user), name: 'Laptop').first

      user.api_tokens.revoke_all!

      expect(mine.map { |token| token.reload.revoked_at }).to all(be_present)
      expect(theirs.reload.revoked_at).to be_nil
    end
  end

  it 'is destroyed with its user' do
    described_class.issue!(user, name: 'Laptop')

    expect { user.destroy }.to change(described_class, :count).by(-1)
  end
end
