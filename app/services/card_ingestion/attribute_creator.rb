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
  end
end
