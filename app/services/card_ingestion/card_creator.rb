module CardIngestion
  class CardCreator < Service
    ERROR_IMAGE_URL = 'https://errors.scryfall.com/soon.jpg'.freeze

    def initialize(boxset:, card_data:, is_token: false)
      @boxset = boxset
      @card_data = card_data
      @is_token = is_token
    end

    def call
      existing_card = MagicCard.find_by(card_uuid: @card_data['uuid'])

      if existing_card
        update_existing_card(existing_card)
      else
        create_new_card
      end
    end

    private

    def update_existing_card(existing_card)
      card_obj = build_card_attributes
      card_obj.merge!(fetch_images_with_timestamp) if needs_image_update?(existing_card)

      existing_card.update(card_obj)
      existing_card
    end

    def create_new_card
      puts "creating new #{@is_token ? 'token' : 'card'} #{@card_data['name']}"

      card_obj = build_card_attributes
                 .merge(fetch_images_with_timestamp)
                 .merge(normal_price: 0, foil_price: 0)

      MagicCard.create(card_obj)
    end

    def build_card_attributes
      AttributeMapper.call(boxset: @boxset, card_data: @card_data, is_token: @is_token)
    end

    def fetch_images_with_timestamp
      images = Scryfall::ImageFetcher.call(card_data: @card_data)

      {
        image_large: images[:large],
        image_medium: images[:normal],
        image_small: images[:small],
        art_crop: images[:art_crop],
        image_updated_at: Time.now
      }
    end

    def needs_image_update?(card)
      missing_images?(card) || images_stale?(card) || error_image?(card)
    end

    def missing_images?(card)
      [card.image_large, card.image_medium, card.image_small, card.art_crop].any?(&:nil?)
    end

    def images_stale?(card)
      card.image_updated_at.present? && card.image_updated_at < 90.days.ago
    end

    def error_image?(card)
      [card.image_large, card.image_medium, card.image_small].any? { |img| img == ERROR_IMAGE_URL }
    end
  end
end
