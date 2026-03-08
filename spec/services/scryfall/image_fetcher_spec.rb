require 'rails_helper'

RSpec.describe Scryfall::ImageFetcher, type: :service do
  let(:scryfall_id) { SecureRandom.uuid }
  let(:card_data) do
    {
      'name' => 'Lightning Bolt',
      'identifiers' => { 'scryfallId' => scryfall_id }
    }
  end

  context 'when scryfall_id is missing' do
    let(:card_data) { { 'name' => 'Test', 'identifiers' => {} } }

    it 'returns empty images' do
      result = described_class.call(card_data: card_data)
      expect(result).to eq({ small: nil, normal: nil, large: nil, art_crop: nil })
    end
  end

  context 'when scryfall returns a single-face card' do
    let(:scryfall_response) do
      {
        'image_uris' => {
          'small' => 'https://example.com/small.jpg',
          'normal' => 'https://example.com/normal.jpg',
          'large' => 'https://example.com/large.jpg',
          'art_crop' => 'https://example.com/art.jpg'
        }
      }
    end

    before do
      allow(HTTParty).to receive(:get).and_return(scryfall_response)
      allow_any_instance_of(described_class).to receive(:sleep)
    end

    it 'extracts image URLs' do
      result = described_class.call(card_data: card_data)
      expect(result[:small]).to eq('https://example.com/small.jpg')
      expect(result[:large]).to eq('https://example.com/large.jpg')
    end
  end

  context 'when scryfall returns a double-face card' do
    let(:card_data) do
      {
        'name' => 'Delver of Secrets',
        'identifiers' => { 'scryfallId' => scryfall_id },
        'otherFaceIds' => ['other-uuid'],
        'side' => 'a'
      }
    end

    let(:scryfall_response) do
      {
        'card_faces' => [
          {
            'image_uris' => {
              'small' => 'https://example.com/front_small.jpg',
              'normal' => 'https://example.com/front_normal.jpg',
              'large' => 'https://example.com/front_large.jpg',
              'art_crop' => 'https://example.com/front_art.jpg'
            }
          },
          {
            'image_uris' => {
              'small' => 'https://example.com/back_small.jpg',
              'normal' => 'https://example.com/back_normal.jpg',
              'large' => 'https://example.com/back_large.jpg',
              'art_crop' => 'https://example.com/back_art.jpg'
            }
          }
        ]
      }
    end

    before do
      allow(HTTParty).to receive(:get).and_return(scryfall_response)
      allow_any_instance_of(described_class).to receive(:sleep)
    end

    it 'extracts front face images for side a' do
      result = described_class.call(card_data: card_data)
      expect(result[:small]).to eq('https://example.com/front_small.jpg')
    end
  end
end
