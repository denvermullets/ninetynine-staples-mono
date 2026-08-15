require 'rails_helper'

# End to end over the real queries: candidates, themes, profile and tribes. The examples that matter
# are the ones about ORDER, because the whole point of Stage 3 is that two commanders sharing a colour
# identity must not come out identical - buildability alone cannot tell them apart.
RSpec.describe Commanders::Discovery, type: :service do
  let(:user) { create(:user, username: 'brewer') }
  let(:collection) { create(:collection, user: user) }

  def bits(*letters)
    letters.sum { |letter| Commanders::ColorMask::BITS.fetch(letter) }
  end

  def color(letter)
    @colors ||= {}
    @colors[letter] ||= Color.find_by(name: letter) || create(:color, name: letter)
  end

  def paint(card, letters)
    letters.each { |letter| MagicCardColorIdent.create!(magic_card: card, color: color(letter)) }
    card
  end

  def commander(name:, colors: [], roles: [], rank: 2_000, **attributes)
    card = create(:magic_card, { name: name, scryfall_oracle_id: SecureRandom.uuid, text: '',
                                 can_be_commander: true, edhrec_rank: rank }.merge(attributes))
    roles.each do |role, effect|
      create(:card_role, scryfall_oracle_id: card.scryfall_oracle_id, role: role, effect: effect)
    end
    paint(card, colors)
  end

  def own(colors: [], roles: [], sub_type: nil, name: 'Owned Card')
    card = create(:magic_card, name: name, scryfall_oracle_id: SecureRandom.uuid,
                               card_type: 'Creature - Thing')
    roles.each do |role, effect|
      create(:card_role, scryfall_oracle_id: card.scryfall_oracle_id, role: role, effect: effect)
    end
    attach_sub_type(card, sub_type) if sub_type
    create(:collection_magic_card, collection: collection, magic_card: card)
    paint(card, colors)
  end

  def attach_sub_type(card, name)
    sub_type = SubType.find_by(name: name) || SubType.create!(name: name)
    MagicCardSubType.create!(magic_card: card, sub_type: sub_type)
  end

  def discover(**)
    described_class.call(collection_ids: [collection.id], **)
  end

  def names(result)
    result[:rows].pluck(:name)
  end

  describe 'the candidate universe' do
    it 'lists commanders, not every card in the database' do
      commander(name: 'Legend', colors: ['B'])
      create(:magic_card, name: 'Not A Commander', scryfall_oracle_id: SecureRandom.uuid)

      expect(names(discover)).to eq(['Legend'])
    end

    it 'lists a commander once however many times it has been reprinted' do
      first = commander(name: 'Legend', colors: ['B'])
      paint(create(:magic_card, name: 'Legend', scryfall_oracle_id: first.scryfall_oracle_id,
                                can_be_commander: true), ['B'])

      expect(names(discover)).to eq(['Legend'])
    end

    it 'leaves out the back face of a double-faced commander' do
      commander(name: 'Front', colors: ['B'])
      commander(name: 'Back', colors: ['B'], card_side: 'b')

      expect(names(discover)).to eq(['Front'])
    end
  end

  describe 'differentiating commanders that share an identity' do
    # THE POINT OF THE WHOLE STAGE. Buildability is derived from the colour identity mask, so these
    # two have identical pools, identical completeness and identical bottlenecks. Only theme fit can
    # separate them, and the collection is deep in sacrifice and empty of counterspells.
    before do
      commander(name: 'Sac Lord', colors: ['B'], roles: [%w[sacrifice sacrifice_outlet]])
      commander(name: 'Counter Lord', colors: ['B'], roles: [%w[protection counterspell]])
      8.times { |i| own(colors: ['B'], roles: [%w[sacrifice sacrifice_outlet]], name: "Outlet #{i}") }
    end

    it 'gives them the same completeness, because that is a property of the identity' do
      rows = discover[:rows].index_by { |row| row[:name] }

      expect(rows['Sac Lord'][:completeness]).to eq(rows['Counter Lord'][:completeness])
    end

    it 'still ranks the one the collection actually supports first' do
      expect(names(discover).first).to eq('Sac Lord')
    end

    it 'says which theme carried it' do
      row = discover[:rows].find { |entry| entry[:name] == 'Sac Lord' }

      expect(row[:matched].first).to include(label: 'Sacrifice outlet', owned: 8)
    end
  end

  describe 'tribal themes' do
    it 'ranks a commander whose named creature type fills the collection above one it does not' do
      commander(name: 'Goblin Lord', colors: ['R'], text: 'Goblins you control get +1/+1.')
      commander(name: 'Elf Lord', colors: ['R'], text: 'Elves you control get +1/+1.')
      8.times { |i| own(colors: ['R'], sub_type: 'Goblin', name: "Goblin #{i}") }

      expect(names(discover).first).to eq('Goblin Lord')
    end

    # A commander whose type line says Goblin but whose rules text never mentions one is not a tribal
    # commander, per CommanderThemes' reasoning about Atraxa.
    it 'ignores a creature type the commander does not name in its rules text' do
      commander(name: 'Silent Goblin', colors: ['R'], text: 'Flying.')
      8.times { |i| own(colors: ['R'], sub_type: 'Goblin', name: "Goblin #{i}") }

      expect(discover[:rows].first[:matched]).to be_empty
    end
  end

  describe 'colour identity as a hard gate' do
    it 'does not credit a commander with cards outside its identity' do
      commander(name: 'Mono Black', colors: ['B'])
      own(colors: ['G'], roles: [%w[ramp land_ramp]])

      expect(discover[:rows].first[:owned_pool]).to eq(0)
    end

    it 'credits a colourless card to a coloured commander' do
      commander(name: 'Mono Black', colors: ['B'])
      own(roles: [%w[ramp mana_rock]])

      expect(discover[:rows].first[:owned_pool]).to eq(1)
    end
  end

  describe 'sorting' do
    before do
      commander(name: 'Staple', colors: ['B'], rank: 50)
      commander(name: 'Sleeper', colors: ['B'], rank: 2_500)
      own(colors: ['B'], roles: [%w[ramp mana_rock]])
    end

    # Obscurity peaks in the middle of the rank range, so the format's most played commander scores
    # near zero on it and the mid-rank one wins.
    it 'puts the underplayed commander first on hipster' do
      expect(names(discover(sort: 'hipster')).first).to eq('Sleeper')
    end

    it 'puts the most played commander first on rank' do
      expect(names(discover(sort: 'rank')).first).to eq('Staple')
    end

    it 'falls back to the default sort when handed something it does not know' do
      expect(names(discover(sort: 'nonsense'))).to eq(names(discover(sort: 'buildable')))
    end
  end

  describe 'filters' do
    it 'narrows to a rank band' do
      commander(name: 'Staple', colors: ['B'], rank: 50)
      commander(name: 'Sleeper', colors: ['B'], rank: 20_000)

      expect(names(discover(band: 'obscure'))).to eq(['Sleeper'])
    end

    # Subset, not intersection: picking mono-black means "commanders I could sleeve up in black or
    # inside it". A Golgari commander is not a mono-black brew.
    it 'narrows to commanders that fit inside the chosen colours' do
      commander(name: 'Mono Black', colors: ['B'])
      commander(name: 'Golgari', colors: %w[B G])

      expect(names(discover(colors: bits('B')))).to eq(['Mono Black'])
    end

    it 'narrows to commanders the collection actually holds a copy of' do
      owned = commander(name: 'Owned', colors: ['B'])
      commander(name: 'Unowned', colors: ['B'])
      create(:collection_magic_card, collection: collection, magic_card: owned)

      expect(names(discover(owned_only: true))).to eq(['Owned'])
    end

    it 'reports how many commanders survived the completeness floor against how many there are' do
      commander(name: 'Legend', colors: ['B'])

      expect(discover(min_completeness: 0.9)).to include(total: 1, matched: 0)
    end
  end
end
