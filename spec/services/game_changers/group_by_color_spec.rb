require 'rails_helper'

RSpec.describe GameChangers::GroupByColor, type: :service do
  def card_for(game_changer, card_type:, colors: [], identity: [])
    create(:magic_card, scryfall_oracle_id: game_changer.oracle_id, card_type: card_type).tap do |card|
      colors.each { |name| MagicCardColor.create!(magic_card: card, color: Color.find_or_create_by!(name: name)) }
      identity.each do |name|
        MagicCardColorIdent.create!(magic_card: card, color: Color.find_or_create_by!(name: name))
      end
    end
  end

  let(:red_changer) { create(:game_changer) }
  let(:blue_changer) { create(:game_changer) }
  let(:land_changer) { create(:game_changer) }
  let(:green_land_changer) { create(:game_changer) }

  before do
    # mono-red by color, red-green by identity
    card_for(red_changer, card_type: 'Creature', colors: %w[R], identity: %w[R G])
    card_for(blue_changer, card_type: 'Instant', colors: %w[U], identity: %w[U])
    card_for(land_changer, card_type: 'Land')
    card_for(green_land_changer, card_type: 'Land', identity: %w[G])
  end

  let(:result) do
    described_class.call(game_changers: [red_changer, blue_changer, land_changer, green_land_changer]).to_h
  end

  it 'groups by color identity rather than card color' do
    expect(result['Multicolor']).to eq([red_changer])
    expect(result).not_to have_key('Red')
  end

  it 'spells the color out' do
    expect(result['Blue']).to eq([blue_changer])
  end

  it 'puts a land with a colored identity under that color' do
    expect(result['Green']).to eq([green_land_changer])
  end

  it 'puts a land with no identity under Land' do
    expect(result['Land']).to eq([land_changer])
  end

  it 'orders the groups' do
    expect(result.keys).to eq(%w[Blue Green Multicolor Land])
  end
end
