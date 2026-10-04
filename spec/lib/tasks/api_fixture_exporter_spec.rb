require 'rails_helper'
require Rails.root.join('lib/tasks/api_fixture_exporter').to_s

RSpec.describe ApiFixtureExporter do
  let(:out_dir) { Pathname(Dir.mktmpdir) }
  let(:owner) { create(:user, username: 'realname', email: 'real@person.test', preferences: { 'theme' => 'light' }) }
  let(:commander) do
    create(:magic_card, name: 'Atraxa', card_uuid: SecureRandom.uuid, scryfall_oracle_id: SecureRandom.uuid)
  end
  let(:deck) do
    create(:collection, user: owner, collection_type: 'commander_deck', is_public: false).tap do |deck|
      create(:collection_magic_card, collection: deck, magic_card: commander, board_type: 'commander')
    end
  end
  let!(:precon) do
    create(:precon_deck, deck_type: 'Commander Deck').tap do |precon|
      PreconDeckCard.create!(precon_deck: precon, magic_card: commander, board_type: 'commander', quantity: 1)
    end
  end

  after { FileUtils.rm_rf(out_dir) }

  def fixture(file)
    JSON.parse(out_dir.join(file).read)
  end

  it 'writes a schema-checked fixture per endpoint, plus the schemas' do
    index = described_class.new(deck_ids: [deck.id.to_s], out_dir: out_dir).call

    expect(index.keys).to include('me.json', 'decks.json', "deck_#{deck.id}.json", "precon_deck_#{precon.id}.json",
                                  'cards_batch.json', 'tokens.json', 'session.json')
    expect(fixture('index.json')).to eq(index)
    expect(fixture("deck_#{deck.id}.json")['cards'].first['card']['name']).to eq('Atraxa')
    expect(fixture('cards_batch.json')['missing']).to eq([described_class::UNKNOWN_ID])
    expect(out_dir.join('schemas').children.map { |path| path.basename('.json').to_s }).to match_array(ApiSchemas.names)
  end

  it 'scrubs the user and leaves no tokens behind' do
    described_class.new(deck_ids: [deck.id], out_dir: out_dir).call

    expect(fixture('me.json')).to include('id' => 1, 'username' => 'player', 'email' => 'player@example.com',
                                          'preferences' => UserPreferences::DEFAULT_PREFERENCES)
    expect(fixture('session.json')['user']).to eq(described_class::SCRUBBED_USER)
    expect(out_dir.glob('*.json').map(&:read).join).not_to include('realname', 'real@person.test')
    expect(ApiToken.count).to eq(0)
  end

  it 'needs a deck id' do
    expect { described_class.new(deck_ids: [], out_dir: out_dir) }.to raise_error(ArgumentError)
  end
end
