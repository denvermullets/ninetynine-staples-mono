require 'rails_helper'

# boxset_card renders the details partial on its own (no layout), which is what an expanded table row loads
RSpec.describe 'Oracle tags on the card details panel', type: :request do
  let(:card) { create(:magic_card, name: 'Doom Blade', scryfall_oracle_id: SecureRandom.uuid, card_side: nil) }
  let(:spot_removal) do
    create(:oracle_tag, slug: 'spot-removal', label: 'spot removal', description: 'Removes one thing.')
  end

  it 'shows Scryfall tags linked back to Tagger' do
    create(:card_oracle_tag, oracle_tag: spot_removal, scryfall_oracle_id: card.scryfall_oracle_id)

    get boxset_magic_card_path(card.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('spot removal')
    expect(response.body).to include('https://tagger.scryfall.com/tags/card/spot-removal')
  end

  it 'hides disabled tags' do
    spot_removal.update!(disabled: true)
    create(:card_oracle_tag, oracle_tag: spot_removal, scryfall_oracle_id: card.scryfall_oracle_id)

    get boxset_magic_card_path(card.id)

    expect(response.body).not_to include('spot removal')
  end

  it 'still renders the tags wrapper for a card with no tags' do
    get boxset_magic_card_path(card.id)

    expect(response.body).to include("oracle_tags_#{card.id}")
  end
end
