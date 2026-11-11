require 'rails_helper'

RSpec.describe Decks::Grouping, type: :service do
  let(:user) { create(:user) }

  def deck(name, **attrs)
    create(:collection, user: user, name: name, collection_type: 'commander_deck', **attrs)
  end

  def tag(name)
    Tag.create!(name: name)
  end

  def group(decks, by:, color_identities: {})
    described_class.call(decks: decks, by: by, color_identities: color_identities)
  end

  def summary(groups)
    groups.map { |g| [g.label, g.decks.map(&:name)] }
  end

  it 'returns nothing for no decks' do
    expect(group([], by: 'tag')).to eq([])
  end

  it 'puts every deck in one group, in the order given, when not grouping' do
    decks = [deck('B'), deck('A')]

    expect(summary(group(decks, by: 'none'))).to eq([['All Decks', %w[B A]]])
  end

  it 'falls back to no grouping for an unknown option' do
    expect(group([deck('A')], by: 'nonsense').map(&:key)).to eq(['all'])
  end

  describe 'by tag' do
    it 'lists a multi-tagged deck under each tag, tags A-Z, untagged last' do
      combo = tag('combo')
      budget = tag('Budget')
      both = deck('Both', tags: [combo, budget])
      only_combo = deck('Only combo', tags: [combo])
      none = deck('None')

      groups = group([both, only_combo, none], by: 'tag')

      expect(summary(groups)).to eq([
                                      ['Budget', ['Both']],
                                      ['combo', ['Both', 'Only combo']],
                                      ['Untagged', ['None']]
                                    ])
      expect(groups.first.tag).to eq(budget)
    end
  end

  describe 'by color identity' do
    it 'orders colourless, then by colour count, then WUBRG; decks with no cards last' do
      decks = [deck('Jund'), deck('Green'), deck('Blue'), deck('Artifacts'), deck('Empty'), deck('Simic')]
      identities = {
        decks[0].id => 'BRG', decks[1].id => 'G', decks[2].id => 'U',
        decks[3].id => 'C', decks[5].id => 'UG'
      }

      groups = group(decks, by: 'color', color_identities: identities)

      expect(summary(groups)).to eq([
                                      ['C', ['Artifacts']], ['U', ['Blue']], ['G', ['Green']],
                                      ['UG', ['Simic']], ['BRG', ['Jund']], ['No cards yet', ['Empty']]
                                    ])
      expect(groups.first.color_identity).to eq('C')
    end
  end

  describe 'by bracket' do
    it 'orders brackets ascending with unbracketed decks last' do
      decks = [deck('Four', bracket_level: 4), deck('Unset'), deck('Two', bracket_level: 2)]

      expect(summary(group(decks, by: 'bracket'))).to eq([
                                                           ['Bracket 2', ['Two']],
                                                           ['Bracket 4', ['Four']],
                                                           ['No bracket', ['Unset']]
                                                         ])
    end
  end

  describe 'by format' do
    it 'puts commander decks first' do
      decks = [deck('Sixty', collection_type: 'deck'), deck('EDH')]

      expect(summary(group(decks, by: 'format'))).to eq([['Commander', ['EDH']], ['Deck', ['Sixty']]])
    end
  end
end
