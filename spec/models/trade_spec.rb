require 'rails_helper'

RSpec.describe Trade, type: :model do
  let(:proposer) { create(:user, username: 'proposer') }
  let(:recipient) { create(:user, username: 'recipient') }
  let(:trade) { create(:trade, proposer: proposer, recipient: recipient) }

  describe 'validations' do
    it 'refuses a trade with itself' do
      solo = build(:trade, proposer: proposer, recipient: proposer)
      expect(solo).not_to be_valid
      expect(solo.errors[:proposer_id]).to be_present
    end

    it 'refuses a status outside the enum' do
      expect { build(:trade, status: 'haggling') }.to raise_error(ArgumentError)
    end
  end

  describe '#open?' do
    it 'is open while proposed' do
      expect(trade).to be_open
    end

    it 'is open while accepted' do
      expect(create(:trade, :accepted)).to be_open
    end

    %w[declined cancelled completed].each do |status|
      it "is closed once #{status}" do
        expect(create(:trade, status: status)).not_to be_open
      end
    end
  end

  describe '#counterparty' do
    it 'gives the proposer the recipient' do
      expect(trade.counterparty(proposer)).to eq(recipient)
    end

    it 'gives the recipient the proposer' do
      expect(trade.counterparty(recipient)).to eq(proposer)
    end

    it 'gives an outsider nobody' do
      expect(trade.counterparty(create(:user, username: 'nosy'))).to be_nil
    end
  end

  describe '#side_for' do
    it 'names each party' do
      expect(trade.side_for(proposer)).to eq('proposer')
      expect(trade.side_for(recipient)).to eq('recipient')
    end

    it 'has no side for an outsider' do
      expect(trade.side_for(create(:user, username: 'nosy'))).to be_nil
    end
  end

  describe 'user associations' do
    it 'reaches the trade from both users' do
      trade
      expect(proposer.proposed_trades).to contain_exactly(trade)
      expect(recipient.received_trades).to contain_exactly(trade)
    end
  end

  describe '.open' do
    it 'lists only proposed and accepted trades' do
      live = [create(:trade), create(:trade, :accepted)]
      %w[declined cancelled completed].each { |status| create(:trade, status: status) }
      expect(described_class.open).to match_array(live)
    end
  end
end
