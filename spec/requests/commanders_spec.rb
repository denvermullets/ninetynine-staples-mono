require 'rails_helper'

# Stream responses only - a full /commanders render needs the built stylesheet, which CI does not have.
RSpec.describe 'Commanders', type: :request do
  let(:commander_legality) { Legality.find_or_create_by!(name: 'commander') }
  let(:partner_text) { 'Partner (You can have two commanders if both have partner.)' }

  before { Rails.cache.clear }

  def commander(name, colors, text: '')
    card = create(:magic_card, name: name, text: text, can_be_commander: true)
    colors.each do |letter|
      color = Color.find_by(name: letter) || create(:color, name: letter)
      MagicCardColorIdent.create!(magic_card: card, color: color)
      MagicCardColor.create!(magic_card: card, color: color)
    end
    MagicCardLegality.create!(magic_card: card, legality: commander_legality, status: 'Legal')
    card
  end

  def load(**params)
    get load_commanders_path, params: params, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
  end

  describe 'GET /load_commanders with partner' do
    before do
      commander('Thrasios, Triton Hero', %w[G U], text: partner_text)
      commander('Tymna the Weaver', %w[W B], text: partner_text)
      commander('Kraum, Ludevic', %w[U R], text: partner_text)
      commander('Atraxa, Grand Unifier', %w[W U B G])
    end

    it 'lists the partners whose pair reaches the selected colours, and says who completes them' do
      load(partner: 'true', mana: %w[W U B G])

      expect(response.body).to include('Thrasios, Triton Hero', 'Tymna the Weaver', 'Pairs with')
      expect(response.body).not_to include('Kraum, Ludevic', 'Atraxa, Grand Unifier')
    end

    it 'leaves the ordinary colour filter alone without it' do
      load(mana: %w[W U B G], exact_color_match: 'true')

      expect(response.body).to include('Atraxa, Grand Unifier')
      expect(response.body).not_to include('Thrasios, Triton Hero', 'Pairs with')
    end
  end
end
