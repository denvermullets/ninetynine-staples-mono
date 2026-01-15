module CardIngestion
  class AttributeCreator < Service
    def initialize(magic_card:, card_data:)
      @magic_card = magic_card
      @card_data = card_data
    end

    def call
      create_artist
      create_subtypes
      create_supertypes
      create_types
      create_colors
      create_color_identities
      create_keywords
      create_legalities
      create_finishes
      create_frame_effects
      create_rulings
      create_variations

      @magic_card
    end

    private

    def create_artist
      artist_name = @card_data['artist']
      return unless artist_name.present?

      artist = Artist.where('LOWER(name) = LOWER(?)', artist_name).first ||
               Artist.create(name: artist_name)

      MagicCardArtist.find_or_create_by(artist: artist, magic_card: @magic_card)
    end

    def create_subtypes
      @card_data['subtypes']&.each do |sub_type_name|
        sub_type = SubType.find_or_create_by(name: sub_type_name)
        MagicCardSubType.find_or_create_by(magic_card: @magic_card, sub_type: sub_type)
      end
    end

    def create_supertypes
      @card_data['supertypes']&.each do |super_type_name|
        super_type = SuperType.find_or_create_by(name: super_type_name)
        MagicCardSuperType.find_or_create_by(magic_card: @magic_card, super_type: super_type)
      end
    end

    def create_types
      @card_data['types']&.each do |type_name|
        card_type = CardType.find_or_create_by(name: type_name)
        MagicCardType.find_or_create_by(magic_card: @magic_card, card_type: card_type)
      end
    end

    def create_colors
      @card_data['colors']&.each do |color_name|
        color = Color.find_or_create_by(name: color_name)
        MagicCardColor.find_or_create_by(color: color, magic_card: @magic_card)
      end
    end

    def create_color_identities
      @card_data['colorIdentity']&.each do |color_name|
        color = Color.find_or_create_by(name: color_name)
        MagicCardColorIdent.find_or_create_by(color: color, magic_card: @magic_card)
      end
    end

    def create_keywords
      @card_data['keywords']&.each do |keyword_name|
        keyword = Keyword.find_or_create_by(keyword: keyword_name)
        MagicCardKeyword.find_or_create_by(magic_card: @magic_card, keyword: keyword)
      end
    end

    def create_legalities
      @card_data['legalities']&.each do |format_name, status|
        legality = Legality.find_or_create_by(name: format_name)
        MagicCardLegality.upsert(
          { magic_card_id: @magic_card.id, legality_id: legality.id, status: status },
          unique_by: %i[magic_card_id legality_id]
        )
      end
    end

    def create_finishes
      @card_data['finishes']&.each do |finish_name|
        finish = Finish.find_or_create_by(name: finish_name)
        MagicCardFinish.find_or_create_by(magic_card: @magic_card, finish: finish)
      end
    end

    def create_frame_effects
      @card_data['frameEffects']&.each do |effect_name|
        frame_effect = FrameEffect.find_or_create_by(name: effect_name)
        MagicCardFrameEffect.find_or_create_by(magic_card: @magic_card, frame_effect: frame_effect)
      end
    end

    def create_rulings
      @card_data['rulings']&.each do |ruling_data|
        ruling = Ruling.find_or_create_by(
          ruling: ruling_data['text'],
          ruling_date: ruling_data['date']
        )
        MagicCardRuling.find_or_create_by(magic_card: @magic_card, ruling: ruling)
      end
    end

    def create_variations
      @card_data['variations']&.each do |variation_uuid|
        variation = MagicCard.find_by(card_uuid: variation_uuid)
        next unless variation

        MagicCardVariation.find_or_create_by(magic_card: @magic_card, variation: variation)
      end
    end
  end
end
