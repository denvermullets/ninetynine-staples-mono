require 'rails_helper'

RSpec.describe Decklist::Resolve, type: :service do
  def card(name, oracle_id: SecureRandom.uuid, **attributes)
    create(:magic_card, name: name, scryfall_oracle_id: oracle_id, **attributes)
  end

  def resolve(text)
    described_class.call(entries: Decklist::Parse.call(text: text))
  end

  it 'hands back each resolved entry with its oracle id' do
    ring = card('Sol Ring')

    expect(resolve('2 sol ring')).to eq(
      resolved: [{ name: 'sol ring', quantity: 2, board: 'mainboard', oracle_id: ring.scryfall_oracle_id }],
      ambiguous: [], unresolved: []
    )
  end

  it 'resolves many printings of one card to its one oracle id' do
    oracle_id = SecureRandom.uuid
    card('Sol Ring', oracle_id: oracle_id)
    card('Sol Ring', oracle_id: oracle_id)

    expect(resolve('Sol Ring')[:resolved].map { |entry| entry[:oracle_id] }).to eq([oracle_id])
  end

  it 'prefers a full name over a face of another card' do
    ice = card('Ice')
    card('Fire // Ice', face_name: 'Ice', card_side: 'b')

    expect(resolve('Ice')[:resolved].map { |entry| entry[:oracle_id] }).to eq([ice.scryfall_oracle_id])
  end

  describe 'a split card' do
    let(:oracle_id) { SecureRandom.uuid }

    before do
      card('Fire // Ice', oracle_id: oracle_id, face_name: 'Fire', card_side: 'a')
      card('Fire // Ice', oracle_id: oracle_id, face_name: 'Ice', card_side: 'b')
    end

    it 'resolves from its front face alone' do
      expect(resolve('Fire')[:resolved].map { |entry| entry[:oracle_id] }).to eq([oracle_id])
    end

    it 'keeps one entry per typed name when two names land on it' do
      resolved = resolve("1 Fire // Ice\n2 Ice")[:resolved]

      expect(resolved).to eq([{ name: 'Fire // Ice', quantity: 1, board: 'mainboard', oracle_id: oracle_id },
                              { name: 'Ice', quantity: 2, board: 'mainboard', oracle_id: oracle_id }])
    end
  end

  it 'reports a name on two oracle ids as ambiguous' do
    card('Scavenger Hunt')
    card('Scavenger Hunt')

    result = resolve('2 Scavenger Hunt')

    expect(result[:resolved]).to be_empty
    expect(result[:ambiguous]).to eq([{ name: 'Scavenger Hunt', quantity: 2, board: 'mainboard' }])
  end

  it 'never matches a token' do
    card('Treasure', is_token: true)

    expect(resolve('Treasure')[:unresolved].map { |entry| entry[:name] }).to eq(['Treasure'])
  end

  it 'never matches a printing with no oracle id' do
    card('Sol Ring', oracle_id: nil)

    expect(resolve('Sol Ring')[:unresolved].map { |entry| entry[:name] }).to eq(['Sol Ring'])
  end

  it 'reports an unknown name as unresolved' do
    expect(resolve('3 Not A Real Card')).to eq(
      resolved: [], ambiguous: [], unresolved: [{ name: 'Not A Real Card', quantity: 3, board: 'mainboard' }]
    )
  end

  it 'runs no query for an empty list' do
    expect(described_class.call(entries: {})).to eq(resolved: [], ambiguous: [], unresolved: [])
  end

  it 'exposes the printings a name may resolve to' do
    ring = card('Sol Ring')
    card('Treasure', is_token: true)
    card('Oddity', oracle_id: nil)

    expect(described_class.candidates).to contain_exactly(ring)
  end
end
