require 'rails_helper'

RSpec.describe DevSeeds::NetBots, type: :service do
  def create_commander_precon(name)
    precon = PreconDeck.create!(code: name.first(3).upcase, file_name: name.parameterize, name: name,
                                deck_type: 'Commander Deck')
    PreconDeckCard.create!(precon_deck: precon, magic_card: create(:magic_card), board_type: 'commander')
    PreconDeckCard.create!(precon_deck: precon, magic_card: create(:magic_card), board_type: 'mainBoard',
                           quantity: 3)
    precon
  end

  before do
    %w[Alpha Beta Gamma].each { |name| create_commander_precon(name) }
  end

  it 'creates the bot users, each with a token and a distinct imported deck' do
    bots = described_class.call

    expect(bots.map { |bot| bot.user.username }).to eq(%w[net-bot-1 net-bot-2 net-bot-3])
    expect(bots.map(&:token)).to all(start_with(ApiToken::PREFIX))
    expect(bots.map { |bot| bot.deck.name }).to eq(%w[Alpha Beta Gamma])
    expect(bots.first.deck.collection_magic_cards.sum(:quantity)).to eq(4)
    expect(Collection.decks).to include(bots.first.deck)
  end

  it 'issues tokens that authenticate as the bot' do
    bot = described_class.call.first

    expect(ApiToken.find_active(bot.token).user).to eq(bot.user)
  end

  it 'is idempotent: a second run adds nothing and issues no new tokens' do
    described_class.call

    expect { @second = described_class.call }.not_to(change { [User.count, ApiToken.count, Collection.count] })
    expect(@second.map(&:token)).to all(be_nil)
    expect(@second.map(&:deck)).to all(be_present)
  end

  it 'issues a fresh token once the old one is revoked' do
    first = described_class.call.first
    first.user.api_tokens.revoke_all!

    expect(described_class.call.first.token).to be_present
  end

  it 'still makes the users and tokens when no Commander precons are ingested' do
    PreconDeck.destroy_all

    bots = described_class.call

    expect(bots.map(&:deck)).to all(be_nil)
    expect(bots.map(&:token)).to all(be_present)
  end

  it 'refuses to run in production' do
    allow(Rails.env).to receive(:production?).and_return(true)

    expect { described_class.call }.to raise_error(/production/)
  end
end
