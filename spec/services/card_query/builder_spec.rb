require 'rails_helper'

RSpec.describe CardQuery::Builder, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:boxset) { create(:boxset, code: 'LEA') }

  # a plain, ungrouped relation - enough for every card-level predicate
  let(:cards) { MagicCard.all }

  def build(query, relation: cards)
    described_class.call(cards: relation, terms: CardQuery::Parser.call(query: query).terms)
  end

  def owned(card, quantity: 1, foil_quantity: 0, **attrs)
    create(:collection_magic_card, collection: collection, magic_card: card,
                                   quantity: quantity, foil_quantity: foil_quantity, **attrs)
  end

  # types live in three normalized tables; card_type is only the display string
  def typed(card, types: [], sub_types: [], super_types: [])
    types.each { |n| MagicCardType.create!(magic_card: card, card_type: CardType.find_or_create_by!(name: n)) }
    sub_types.each { |n| MagicCardSubType.create!(magic_card: card, sub_type: SubType.find_or_create_by!(name: n)) }
    super_types.each do |name|
      MagicCardSuperType.create!(magic_card: card, super_type: SuperType.find_or_create_by!(name: name))
    end
    card
  end

  describe 'card attributes' do
    let!(:goblin) do
      typed(create(:magic_card, name: 'Goblin Guide', card_type: 'Creature - Goblin', rarity: 'rare',
                                mana_value: 1, power: '2', toughness: '2', text: 'Haste.', boxset: boxset),
            types: ['Creature'], sub_types: ['Goblin'])
    end
    let!(:wrath) do
      typed(create(:magic_card, name: 'Wrath of God', card_type: 'Sorcery', rarity: 'uncommon',
                                mana_value: 4, power: nil, toughness: nil, text: 'Destroy all creatures.'),
            types: ['Sorcery'])
    end

    it 'matches card types, sub types and super types alike' do
      expect(build('t:goblin')).to contain_exactly(goblin)
      expect(build('t:creature')).to contain_exactly(goblin)
      expect(build('t:sorcery')).to contain_exactly(wrath)
    end

    it 'matches partial words the way a type line search would' do
      expect(build('t:creat')).to contain_exactly(goblin)
    end

    context 'with a multi-word type' do
      let!(:general) do
        typed(create(:magic_card, name: 'Krenko', card_type: 'Legendary Creature - Goblin Warrior'),
              types: ['Creature'], sub_types: %w[Goblin Warrior], super_types: ['Legendary'])
      end

      # the words land in different tables, so each one is matched independently
      it 'requires every word to match somewhere in the type line' do
        expect(build('t:"legendary creature"')).to contain_exactly(general)
        expect(build('t:"legendary sorcery"')).to be_empty
      end

      it 'combines with negation to exclude a supertype' do
        expect(build('t:goblin -t:legendary')).to contain_exactly(goblin)
      end

      it 'pins the whole name with =' do
        expect(build('t=creature')).to contain_exactly(goblin, general)
        expect(build('t=creat')).to be_empty
      end
    end

    it 'matches oracle text' do
      expect(build('o:haste')).to contain_exactly(goblin)
      expect(build('o:"destroy all"')).to contain_exactly(wrath)
    end

    it 'matches name explicitly' do
      expect(build('n:wrath')).to contain_exactly(wrath)
    end

    it 'compares mana value' do
      expect(build('mv<=2')).to contain_exactly(goblin)
      expect(build('mv:4')).to contain_exactly(wrath)
    end

    it 'compares rarity ordinally' do
      expect(build('r>=rare')).to contain_exactly(goblin)
      expect(build('r:uncommon')).to contain_exactly(wrath)
    end

    it 'filters by set code, case insensitively' do
      expect(build('s:lea')).to contain_exactly(goblin)
    end

    it 'ANDs terms together' do
      expect(build('t:creature r>=rare mv<=2')).to contain_exactly(goblin)
      expect(build('t:creature r:uncommon')).to be_empty
    end

    describe 'negation' do
      it 'excludes matching cards' do
        expect(build('-t:goblin')).to contain_exactly(wrath)
      end

      # a card with no type rows at all is still "not a goblin"
      it 'keeps rows that match nothing' do
        untyped = create(:magic_card, name: 'Mystery', card_type: nil)

        expect(build('-t:goblin')).to contain_exactly(wrath, untyped)
      end
    end

    describe 'power and toughness' do
      it 'compares numerically' do
        expect(build('pow>=2')).to contain_exactly(goblin)
      end

      # "*" and "1+*" must not reach the numeric cast
      it 'drops non-numeric values instead of raising' do
        create(:magic_card, name: 'Tarmogoyf', power: '*', toughness: '1+*')

        expect { build('pow>=1').to_a }.not_to raise_error
        expect(build('pow>=1')).to contain_exactly(goblin)
      end
    end
  end

  describe 'associations' do
    let!(:flier) { create(:magic_card, name: 'Serra Angel') }
    let!(:ground) { create(:magic_card, name: 'Grizzly Bears') }

    it 'matches keywords' do
      MagicCardKeyword.create!(magic_card: flier, keyword: Keyword.create!(keyword: 'Flying'))

      expect(build('kw:flying')).to contain_exactly(flier)
    end

    it 'matches artists' do
      MagicCardArtist.create!(magic_card: flier, artist: Artist.create!(name: 'Douglas Shuler'))

      expect(build('a:shuler')).to contain_exactly(flier)
    end

    it 'matches printing finishes exactly' do
      MagicCardFinish.create!(magic_card: flier, finish: Finish.create!(name: 'foil'))
      MagicCardFinish.create!(magic_card: ground, finish: Finish.create!(name: 'nonfoil'))

      expect(build('finish:foil')).to contain_exactly(flier)
    end

    it 'matches format legality by status' do
      commander = Legality.create!(name: 'commander')
      MagicCardLegality.create!(magic_card: flier, legality: commander, status: 'Legal')
      MagicCardLegality.create!(magic_card: ground, legality: commander, status: 'Banned')

      expect(build('f:commander')).to contain_exactly(flier)
      expect(build('banned:commander')).to contain_exactly(ground)
    end
  end

  describe 'is: flags' do
    let!(:general) { create(:magic_card, name: 'Atraxa', can_be_commander: true) }
    let!(:token) { create(:magic_card, name: 'Soldier', is_token: true) }

    it 'matches boolean columns' do
      expect(build('is:commander')).to contain_exactly(general)
      expect(build('is:token')).to contain_exactly(token)
      expect(build('-is:token')).to contain_exactly(general)
    end

    it 'treats colorless as the absence of color rows' do
      MagicCardColor.create!(magic_card: general, color: Color.find_or_create_by!(name: 'W'))

      expect(build('is:colorless')).to contain_exactly(token)
    end
  end

  describe 'prices' do
    let!(:pricey) { create(:magic_card, name: 'Mox', normal_price: 500, price_change_weekly_normal: 25) }
    let!(:bulk) { create(:magic_card, name: 'Shock', normal_price: 0.1, price_change_weekly_normal: 0) }

    it 'compares price' do
      expect(build('usd>=10')).to contain_exactly(pricey)
    end

    it 'compares weekly price change across both finishes' do
      expect(build('change>=10')).to contain_exactly(pricey)
      expect(build('change<=1')).to contain_exactly(bulk)
    end
  end

  describe 'ownership terms on the grouped collections relation' do
    let!(:playset) do
      typed(create(:magic_card, name: 'Llanowar Elves'), types: ['Creature'], sub_types: %w[Elf Druid])
    end
    let!(:single) do
      typed(create(:magic_card, name: 'Birds of Paradise'), types: ['Creature'], sub_types: ['Bird'])
    end
    let(:other_collection) { create(:collection, user: user) }

    # the same shape CollectionsController#search_magic_cards builds
    let(:grouped) do
      Search::Collection.call(
        cards: MagicCard.joins(collection_magic_cards: :collection).where(collections: { user_id: user.id }),
        search_term: nil, sort_by: :price
      )
    end

    before do
      owned(playset, quantity: 2)
      create(:collection_magic_card, collection: other_collection, magic_card: playset, quantity: 2)
      owned(single, quantity: 1, foil_quantity: 1)
    end

    it 'filters on the summed quantity across the whole scope' do
      expect(build('qty>=4', relation: grouped)).to contain_exactly(playset)
      expect(build('qty>=2', relation: grouped)).to contain_exactly(playset, single)
    end

    it 'filters on foil ownership' do
      expect(build('foil:true', relation: grouped)).to contain_exactly(single)
      expect(build('foil:false', relation: grouped)).to contain_exactly(playset)
    end

    it 'filters on the needed flag' do
      owned(create(:magic_card, name: 'Wanted'), quantity: 0, needed: true)

      expect(build('needed:true', relation: grouped).map(&:name)).to eq(['Wanted'])
    end

    it 'is a no-op when the relation is not grouped' do
      expect { build('qty>=4').to_a }.not_to raise_error
    end

    # The whole reason card predicates are subqueries rather than joins. `playset` sits in two
    # collections and carries two sub types and two keywords, so a join through any of those
    # tables would multiply the rows behind the GROUP BY and report 8 or more copies of 4.
    it 'does not inflate the quantity aggregates' do
      %w[Mana Tap].each do |word|
        MagicCardKeyword.create!(magic_card: playset, keyword: Keyword.create!(keyword: word))
      end

      row = build('t:creature t:elf kw:mana', relation: grouped).first

      expect(row.name).to eq('Llanowar Elves')
      expect(row.quantity).to eq(4)
      expect(row.foil_quantity).to eq(0)
    end
  end

  describe 'with no terms' do
    it 'returns the relation untouched' do
      create(:magic_card, name: 'Anything')

      expect(described_class.call(cards: cards, terms: [])).to eq(cards)
    end
  end

  describe 'card roles' do
    def with_role(name, role, effect, confidence: 0.9)
      card = create(:magic_card, name: name, scryfall_oracle_id: SecureRandom.uuid)
      create(:card_role, scryfall_oracle_id: card.scryfall_oracle_id,
                         role: role, effect: effect, confidence: confidence)
      card
    end

    it 'matches on role' do
      rock = with_role('A Rock', 'ramp', 'mana_rock')
      with_role('A Bolt', 'removal', 'targeted_removal')

      expect(build('role:ramp')).to contain_exactly(rock)
    end

    it 'matches on effect' do
      rock = with_role('A Rock', 'ramp', 'mana_rock')
      with_role('A Dork', 'ramp', 'mana_dork')

      expect(build('effect:mana_rock')).to contain_exactly(rock)
    end

    it 'combines role and effect' do
      rock = with_role('A Rock', 'ramp', 'mana_rock')
      with_role('A Dork', 'ramp', 'mana_dork')

      expect(build('role:ramp effect:mana_rock')).to contain_exactly(rock)
    end

    # A search result is a claim the card does the thing, and below HIGH_CONFIDENCE the rules are guessing.
    it 'ignores low confidence role rows' do
      with_role('A Maybe', 'ramp', 'mana_rock', confidence: 0.5)

      expect(build('role:ramp')).to be_empty
    end

    it 'accepts a spaced effect name' do
      rock = with_role('A Rock', 'ramp', 'mana_rock')

      expect(build('effect:"mana rock"')).to contain_exactly(rock)
    end

    it 'negates with a leading dash' do
      with_role('A Rock', 'ramp', 'mana_rock')
      bolt = with_role('A Bolt', 'removal', 'targeted_removal')

      expect(build('-role:ramp')).to contain_exactly(bolt)
    end
  end

  describe 'commander identity' do
    let(:green) { Color.find_or_create_by!(name: 'G') }
    let(:red) { Color.find_or_create_by!(name: 'R') }

    def with_identity(name, colors, can_be_commander: false)
      card = create(:magic_card, name: name, can_be_commander: can_be_commander)
      colors.each { |color| MagicCardColorIdent.create!(magic_card: card, color: color) }
      card
    end

    before { with_identity('Selvala, Heart of the Wilds', [green], can_be_commander: true) }

    it 'keeps cards inside the commander identity' do
      on_colour = with_identity('Llanowar Elves', [green])
      with_identity('Lightning Bolt', [red])

      expect(build('commander:selvala').where.not(can_be_commander: true)).to contain_exactly(on_colour)
    end

    # Matches Scryfall: a colourless card is legal in every deck.
    it 'keeps colourless cards' do
      colourless = with_identity('Sol Ring', [])

      expect(build('commander:selvala')).to include(colourless)
    end

    it 'resolves a partial name' do
      on_colour = with_identity('Llanowar Elves', [green])

      expect(build('commander:"Selvala, Heart"')).to include(on_colour)
    end

    it 'only resolves against cards that can actually be a commander' do
      with_identity('Selvala Impersonator', [green, red])
      off_colour = with_identity('Lightning Bolt', [red])

      expect(build('commander:selvala')).not_to include(off_colour)
    end

    # Failing open beats returning zero rows for a typo.
    it 'ignores the term when the name resolves to nothing' do
      bolt = with_identity('Lightning Bolt', [red])

      expect(build('commander:notacommander')).to include(bolt)
    end
  end

  # edhrec_rank is an integer column, and binding the value as a Float made Postgres try to read "8000.0"
  # as an integer and raise - so these were errors rather than results.
  describe 'integer column comparisons' do
    it 'compares against edhrec_rank without a type error' do
      obscure = create(:magic_card, name: 'Obscure Thing', edhrec_rank: 9000)
      create(:magic_card, name: 'Staple Thing', edhrec_rank: 12)

      expect(build('rank>8000')).to contain_exactly(obscure)
    end

    it 'still compares against decimal columns' do
      cheap = create(:magic_card, name: 'Cheap Thing', mana_value: 1)
      create(:magic_card, name: 'Costly Thing', mana_value: 6)

      expect(build('mv<=1.5')).to contain_exactly(cheap)
    end
  end
end
