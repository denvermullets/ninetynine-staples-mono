module Scryfall
  class ImageFetcher < Service
    RATE_LIMIT_DELAY = 0.350

    def initialize(card_data:)
      @card_data = card_data
      @scryfall_id = card_data.dig('identifiers', 'scryfallId')
    end

    def call
      return empty_images unless @scryfall_id.present?

      puts "looking up images for #{@card_data['name']}"
      response = fetch_from_scryfall

      images = extract_images(response)
      respect_rate_limit

      images
    end

    private

    def fetch_from_scryfall
      HTTParty.get("https://api.scryfall.com/cards/#{@scryfall_id}")
    end

    def extract_images(response)
      return empty_images unless response

      if single_face_card?(response)
        extract_single_face_images(response)
      elsif double_face_card?(response)
        extract_double_face_images(response)
      else
        empty_images
      end
    end

    def single_face_card?(response)
      response.key?('image_uris') && response['image_uris'].key?('large')
    end

    def double_face_card?(response)
      @card_data['otherFaceIds'] && response['card_faces']&.first&.key?('image_uris')
    end

    def extract_single_face_images(response)
      {
        small: response['image_uris']['small'],
        normal: response['image_uris']['normal'],
        large: response['image_uris']['large'],
        art_crop: response['image_uris']['art_crop']
      }
    end

    def extract_double_face_images(response)
      face_index = @card_data['side'] == 'a' ? 0 : 1
      face = response['card_faces'][face_index]

      {
        small: face['image_uris']['small'],
        normal: face['image_uris']['normal'],
        large: face['image_uris']['large'],
        art_crop: face['image_uris']['art_crop']
      }
    end

    def empty_images
      { small: nil, normal: nil, large: nil, art_crop: nil }
    end

    def respect_rate_limit
      sleep RATE_LIMIT_DELAY
    end
  end
end
