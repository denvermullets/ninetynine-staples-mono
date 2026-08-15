require 'rails_helper'

# The one that exercises the real aggregate. The GROUPING SETS query is the part of this feature most
# able to be quietly wrong - all three grouping levels emit a row with a NULL role for the same mask,
# so the invariants below (role counts never exceeding the card total, effects never collapsing a
# multi-effect card into two) are what pin it down.
RSpec.describe CollectionStats::BuildableProfile, type: :service do
  subject(:profile) { described_class.call(collection_ids: [collection.id]) }

  let(:user) { create(:user, username: 'brewer') }
  let(:collection) { create(:collection, user: user) }

  def bits(*letters)
    letters.sum { |letter| Commanders::ColorMask::BITS.fetch(letter) }
  end

  def color(letter)
    @colors ||= {}
    @colors[letter] ||= Color.find_by(name: letter) || create(:color, name: letter)
  end

  # A card in the collection, identified by its colours and tagged with the roles it fills.
  def own(name:, colors: [], roles: [], quantity: 1)
    card = create(:magic_card, name: name, scryfall_oracle_id: SecureRandom.uuid)
    colors.each { |letter| MagicCardColorIdent.create!(magic_card: card, color: color(letter)) }
    roles.each do |role, effect, confidence|
      create(:card_role, scryfall_oracle_id: card.scryfall_oracle_id, role: role, effect: effect,
                         confidence: confidence || 1.0)
    end
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity)
    card
  end

  it 'returns a bucket for every one of the 32 identities, empty ones included' do
    expect(profile.keys).to match_array(Commanders::ColorMask::MASKS)
  end

  it 'reports nothing owned for a viewer with no collections' do
    empty = described_class.call(collection_ids: [])

    expect(empty.values.sum { |bucket| bucket[:distinct_cards] }).to eq(0)
  end

  describe 'bucketing by identity' do
    it 'files a mono-coloured card under its own colour' do
      own(name: 'Doom Blade', colors: ['B'])

      expect(profile[bits('B')][:distinct_cards]).to eq(1)
    end

    it 'files a two-coloured card under the combined identity, not under either half' do
      own(name: 'Putrefy', colors: %w[B G])

      expect(profile[bits('B')][:distinct_cards]).to eq(0)
      expect(profile[bits('B', 'G')][:distinct_cards]).to eq(1)
    end

    # Colourless cards have no magic_card_color_idents rows at all, so they fall out of an inner join
    # entirely - and they are the cards legal in every deck.
    it 'files a colourless card under mask 0 rather than dropping it' do
      own(name: 'Sol Ring')

      expect(profile[0][:distinct_cards]).to eq(1)
    end
  end

  describe 'counting' do
    # Commander is singleton: a second copy adds nothing to what is buildable.
    it 'counts a card once however many copies are owned' do
      own(name: 'Cultivate', colors: ['G'], quantity: 4)

      expect(profile[bits('G')][:distinct_cards]).to eq(1)
    end

    it 'counts a card once per role however many printings are owned' do
      card = own(name: 'Cultivate', colors: ['G'], roles: [%w[ramp land_ramp]])
      reprint = create(:magic_card, name: 'Cultivate', scryfall_oracle_id: card.scryfall_oracle_id)
      MagicCardColorIdent.create!(magic_card: reprint, color: color('G'))
      create(:collection_magic_card, collection: collection, magic_card: reprint)

      expect(profile[bits('G')][:role_counts]['ramp']).to eq(1)
    end

    # A card tagged both mana_rock and mana_dork is ONE ramp card. Summing its effect counts would
    # count it twice, which is why the role level is its own grouping set rather than a rollup.
    it 'counts a card with two effects in one role as one card of that role' do
      own(name: 'Weird Rock', colors: ['G'], roles: [%w[ramp mana_rock], %w[ramp mana_dork]])

      expect(profile[bits('G')][:role_counts]['ramp']).to eq(1)
    end

    it 'still reports each of that card effects separately' do
      own(name: 'Weird Rock', colors: ['G'], roles: [%w[ramp mana_rock], %w[ramp mana_dork]])

      expect(profile[bits('G')][:effect_counts]).to include(%w[ramp mana_rock] => 1,
                                                            %w[ramp mana_dork] => 1)
    end

    it 'counts a card filling two different roles under both' do
      own(name: 'Skullclamp', roles: [%w[card_draw draw], %w[ramp cost_reduction]])

      expect(profile[0][:role_counts]).to include('card_draw' => 1, 'ramp' => 1)
    end

    it 'counts that card once in the card total' do
      own(name: 'Skullclamp', roles: [%w[card_draw draw], %w[ramp cost_reduction]])

      expect(profile[0][:distinct_cards]).to eq(1)
    end

    # The invariant that catches conflating the grouping sets: the level that aggregated the role
    # away has to be the largest number in the bucket.
    it 'never reports more cards in a role than the bucket holds' do
      own(name: 'Doom Blade', colors: ['B'], roles: [%w[removal targeted_removal]])
      own(name: 'Sign in Blood', colors: ['B'], roles: [%w[card_draw draw]])
      own(name: 'Vanilla', colors: ['B'])

      bucket = profile[bits('B')]

      expect(bucket[:role_counts].values).to all(be <= bucket[:distinct_cards])
    end

    it 'keeps a card with no detected role in the card total' do
      own(name: 'Vanilla', colors: ['B'])

      expect(profile[bits('B')]).to include(distinct_cards: 1, role_counts: {})
    end
  end

  describe 'what is left out' do
    # Below HIGH_CONFIDENCE the pattern rules are guessing, and the 0.5 scry -> card_selection rule
    # alone would bend a collection-wide count out of shape.
    it 'ignores a role tagged below the confidence gate' do
      own(name: 'Preordain', colors: ['U'], roles: [['card_draw', 'card_selection', 0.5]])

      expect(profile[bits('U')][:role_counts]).to be_empty
    end

    it 'still counts that card as owned' do
      own(name: 'Preordain', colors: ['U'], roles: [['card_draw', 'card_selection', 0.5]])

      expect(profile[bits('U')][:distinct_cards]).to eq(1)
    end

    it 'leaves basic lands out entirely - "you own a Forest" is not information' do
      own(name: 'Forest', colors: ['G'], roles: [%w[manabase basic_land]])

      expect(profile[bits('G')][:distinct_cards]).to eq(0)
    end

    # Staged rows are deck-builder scratch and needed rows are wishlist, matching the scope every
    # other panel on the dashboard uses.
    it 'leaves out a card staged into a deck build' do
      card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid)
      MagicCardColorIdent.create!(magic_card: card, color: color('B'))
      create(:collection_magic_card, collection: collection, magic_card: card, staged: true)

      expect(profile[bits('B')][:distinct_cards]).to eq(0)
    end

    it 'leaves out a card only on the wishlist' do
      card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid)
      MagicCardColorIdent.create!(magic_card: card, color: color('B'))
      create(:collection_magic_card, collection: collection, magic_card: card, needed: true)

      expect(profile[bits('B')][:distinct_cards]).to eq(0)
    end

    it 'leaves out a collection the viewer did not ask about' do
      other = create(:collection, user: user, name: 'Other')
      card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid)
      MagicCardColorIdent.create!(magic_card: card, color: color('B'))
      create(:collection_magic_card, collection: other, magic_card: card)

      expect(profile[bits('B')][:distinct_cards]).to eq(0)
    end
  end
end
