require 'rails_helper'

RSpec.describe Decklist::DefaultPrintings, type: :service do
  let(:oracle_id) { SecureRandom.uuid }

  def card(name, oracle_id: SecureRandom.uuid, **attributes)
    create(:magic_card, name: name, scryfall_oracle_id: oracle_id, **attributes)
  end

  def printings(*oracle_ids, **)
    described_class.call(oracle_ids: oracle_ids, **)
  end

  it 'hands back nothing for no oracle ids' do
    card('Sol Ring')

    expect(printings).to eq({})
  end

  it 'hands back one printing per oracle id' do
    ring = card('Sol Ring', oracle_id: oracle_id, normal_price: 1)
    card('Sol Ring', oracle_id: oracle_id, normal_price: 2)
    spell = card('Counterspell')

    expect(printings(oracle_id, spell.scryfall_oracle_id))
      .to eq(oracle_id => ring, spell.scryfall_oracle_id => spell)
  end

  it 'has no entry for an oracle id with no printing' do
    expect(printings(oracle_id)).to eq({})
  end

  it 'never picks a token' do
    card('Treasure', oracle_id: oracle_id, is_token: true)

    expect(printings(oracle_id)).to eq({})
  end

  it 'prefers a priced printing over an unpriced one' do
    card('Sol Ring', oracle_id: oracle_id, normal_price: 0)
    card('Sol Ring', oracle_id: oracle_id, normal_price: nil)
    priced = card('Sol Ring', oracle_id: oracle_id, normal_price: 9)

    expect(printings(oracle_id)[oracle_id]).to eq(priced)
  end

  it 'picks the cheapest priced one' do
    card('Sol Ring', oracle_id: oracle_id, normal_price: 3)
    cheap = card('Sol Ring', oracle_id: oracle_id, normal_price: 1)

    expect(printings(oracle_id)[oracle_id]).to eq(cheap)
  end

  it 'picks the newest one when none is priced' do
    card('Sol Ring', oracle_id: oracle_id, normal_price: 0, boxset: create(:boxset, release_date: '2020-01-01'))
    newest = card('Sol Ring', oracle_id: oracle_id, normal_price: 0,
                              boxset: create(:boxset, release_date: '2025-01-01'))

    expect(printings(oracle_id)[oracle_id]).to eq(newest)
  end

  it 'picks the lowest id when nothing else tells two printings apart' do
    boxset = create(:boxset)
    first = card('Sol Ring', oracle_id: oracle_id, boxset: boxset)
    card('Sol Ring', oracle_id: oracle_id, boxset: boxset)

    expect(printings(oracle_id)[oracle_id]).to eq(first)
  end

  %w[funny memorabilia].each do |set_type|
    it "passes over a cheaper copy from a #{set_type} set" do
      card('Counterspell', oracle_id: oracle_id, normal_price: 1, boxset: create(:boxset, set_type: set_type))
      regular = card('Counterspell', oracle_id: oracle_id, normal_price: 2)

      expect(printings(oracle_id)[oracle_id]).to eq(regular)
    end
  end

  it 'settles for an oddball set when there is no ordinary printing' do
    funny = card('Blast from the Past', oracle_id: oracle_id, boxset: create(:boxset, set_type: 'funny'))

    expect(printings(oracle_id)[oracle_id]).to eq(funny)
  end

  it 'prefers the front face over the back' do
    card('Fire // Ice', oracle_id: oracle_id, face_name: 'Ice', card_side: 'b', normal_price: 1)
    front = card('Fire // Ice', oracle_id: oracle_id, face_name: 'Fire', card_side: 'a', normal_price: 1)

    expect(printings(oracle_id)[oracle_id]).to eq(front)
  end

  it 'prefers a single-faced printing over a back face' do
    card('Sol Ring', oracle_id: oracle_id, card_side: 'b', normal_price: 1)
    single = card('Sol Ring', oracle_id: oracle_id, card_side: nil, normal_price: 5)

    expect(printings(oracle_id)[oracle_id]).to eq(single)
  end

  describe 'except_card_ids' do
    it 'skips the printings in an array' do
      cheap = card('Sol Ring', oracle_id: oracle_id, normal_price: 1)
      other = card('Sol Ring', oracle_id: oracle_id, normal_price: 2)

      expect(printings(oracle_id, except_card_ids: [cheap.id])[oracle_id]).to eq(other)
    end

    it 'skips the printings in a relation' do
      cheap = card('Sol Ring', oracle_id: oracle_id, normal_price: 1)
      other = card('Sol Ring', oracle_id: oracle_id, normal_price: 2)

      expect(printings(oracle_id, except_card_ids: MagicCard.where(id: cheap.id).select(:id))[oracle_id]).to eq(other)
    end

    it 'leaves out a card whose every printing is excepted' do
      ring = card('Sol Ring', oracle_id: oracle_id)

      expect(printings(oracle_id, except_card_ids: [ring.id])).to eq({})
    end
  end

  describe 'preload' do
    it 'loads the associations asked for' do
      card('Sol Ring', oracle_id: oracle_id)

      picked = printings(oracle_id, preload: [:boxset, :colors, { magic_card_color_idents: :color }])[oracle_id]

      expect(picked.association(:boxset)).to be_loaded
      expect(picked.association(:magic_card_color_idents)).to be_loaded
    end

    it 'loads nothing by default' do
      card('Sol Ring', oracle_id: oracle_id)

      expect(printings(oracle_id)[oracle_id].association(:boxset)).not_to be_loaded
    end
  end
end
