require 'rails_helper'

RSpec.describe WantList::BulkImport, type: :service do
  let(:user) { create(:user) }

  def card(name, oracle_id: SecureRandom.uuid, **attributes)
    create(:magic_card, name: name, scryfall_oracle_id: oracle_id, **attributes)
  end

  def import(text)
    described_class.call(user: user, text: text)
  end

  def names(lines)
    lines.map { |line| line[:name] }
  end

  it 'adds an any-printing want for each card with its quantity' do
    bolt = card('Lightning Bolt')
    ring = card('Sol Ring')

    result = import("4 Lightning Bolt\n1x Sol Ring")

    expect(result[:added].map(&:magic_card)).to contain_exactly(bolt, ring)
    expect(user.want_list_items.find_by(magic_card: bolt)).to have_attributes(quantity: 4, any_printing: true)
  end

  it 'reads a line with no quantity as one copy' do
    card('Sol Ring')

    expect(import('Sol Ring')[:added].first.quantity).to eq(1)
  end

  it 'ignores case, curly apostrophes and export noise' do
    card("Urza's Saga")

    result = import('1 URZA’S SAGA (MH2) 259 *F* [Lands] ^Have,#37d67a^')

    expect(result[:added].size).to eq(1)
    expect(result[:unresolved]).to be_empty
  end

  it 'skips blank lines, comments and section headers' do
    card('Sol Ring')

    result = import("Commander\n\n// ramp\n# note\nSIDEBOARD:\n1 Sol Ring")

    expect(result[:added].size).to eq(1)
    expect(result[:unresolved]).to be_empty
  end

  it 'sums repeated lines into one want' do
    card('Sol Ring')

    result = import("1 Sol Ring\n2 Sol Ring")

    expect(result[:added].map(&:quantity)).to eq([3])
  end

  describe 'split and double-faced cards' do
    let(:oracle_id) { SecureRandom.uuid }

    before do
      card('Fire // Ice', oracle_id: oracle_id, face_name: 'Fire', card_side: 'a')
      card('Fire // Ice', oracle_id: oracle_id, face_name: 'Ice', card_side: 'b')
    end

    it 'resolves the full name, however the slashes are spaced' do
      expect(import('1 Fire/Ice')[:added].first.scryfall_oracle_id).to eq(oracle_id)
    end

    it 'resolves either face name to the front face' do
      added = import('1 Ice')[:added].first

      expect(added.magic_card).to have_attributes(card_side: 'a', scryfall_oracle_id: oracle_id)
    end
  end

  it 'reports a name more than one card goes by as ambiguous' do
    card('Scavenger Hunt')
    card('Scavenger Hunt')

    result = import('2 Scavenger Hunt')

    expect(result[:added]).to be_empty
    expect(result[:ambiguous]).to eq([{ name: 'Scavenger Hunt', quantity: 2 }])
  end

  it 'prefers a full name over a face of another card' do
    ice = card('Ice')
    card('Fire // Ice', face_name: 'Ice', card_side: 'b')

    expect(import('Ice')[:added].map(&:magic_card)).to eq([ice])
  end

  it 'reports names it cannot find as typed' do
    result = import("3 Not A Real Card (ABC) 12\n1 Also Fake")

    expect(result[:unresolved]).to eq([{ name: 'Not A Real Card', quantity: 3 }, { name: 'Also Fake', quantity: 1 }])
  end

  it 'does not match tokens' do
    card('Treasure', is_token: true)

    expect(names(import('Treasure')[:unresolved])).to eq(['Treasure'])
  end

  it 'leaves a card the user already wants alone' do
    ring = card('Sol Ring')
    want = create(:want_list_item, :specific_printing, user: user, magic_card: ring, quantity: 1)

    result = import('4 Sol Ring')

    expect(names(result[:already_wanted])).to eq(['Sol Ring'])
    expect(result[:added]).to be_empty
    expect(want.reload).to have_attributes(quantity: 1, any_printing: false)
  end

  describe 'the printing a new want points at' do
    let(:oracle_id) { SecureRandom.uuid }

    it 'is the cheapest priced one' do
      card('Sol Ring', oracle_id: oracle_id, normal_price: 3)
      cheap = card('Sol Ring', oracle_id: oracle_id, normal_price: 1)
      card('Sol Ring', oracle_id: oracle_id, normal_price: 0)

      expect(import('Sol Ring')[:added].first.magic_card).to eq(cheap)
    end

    it 'passes over a cheaper copy from a memorabilia set' do
      card('Counterspell', oracle_id: oracle_id, normal_price: 1, boxset: create(:boxset, set_type: 'memorabilia'))
      regular = card('Counterspell', oracle_id: oracle_id, normal_price: 2)

      expect(import('Counterspell')[:added].first.magic_card).to eq(regular)
    end

    it 'is the newest one when none is priced' do
      card('Sol Ring', oracle_id: oracle_id, normal_price: 0, boxset: create(:boxset, release_date: '2020-01-01'))
      newest = card('Sol Ring', oracle_id: oracle_id, normal_price: 0,
                                boxset: create(:boxset, release_date: '2025-01-01'))

      expect(import('Sol Ring')[:added].first.magic_card).to eq(newest)
    end
  end

  it 'refuses a paste over the limit without adding anything' do
    card('Sol Ring')
    text = (['1 Sol Ring'] + Array.new(described_class::MAX_CARDS) { |i| "1 Card #{i}" }).join("\n")

    expect(import(text)).to eq(success: false, error: 'Paste at most 500 cards at a time.')
    expect(user.want_list_items).to be_empty
  end
end
