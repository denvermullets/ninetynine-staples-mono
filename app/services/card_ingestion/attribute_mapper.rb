module CardIngestion
  class AttributeMapper < Service
    def initialize(boxset:, card_data:, is_token: false)
      @boxset = boxset
      @card_data = card_data
      @is_token = is_token
    end

    def call
      base_attributes.merge(@is_token ? {} : card_specific_attributes)
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def base_attributes
      {
        boxset: @boxset,
        name: @card_data['name'],
        text: @card_data['text'],
        power: @card_data['power'],
        toughness: @card_data['toughness'],
        card_type: @card_data['type'],
        has_foil: @card_data['hasFoil'],
        has_non_foil: @card_data['hasNonFoil'],
        border_color: @card_data['borderColor'],
        frame_version: @card_data['frameVersion'],
        is_reprint: @card_data['isReprint'],
        card_number: @card_data['number'],
        identifiers: @card_data['identifiers'],
        card_uuid: @card_data['uuid'],
        is_token: @is_token,
        face_name: @card_data['faceName'],
        card_side: @card_data['side'],
        other_face_uuid: @card_data.key?('otherFaceIds') ? @card_data['otherFaceIds'].join(',') : nil,
        layout: @card_data['layout'],
        security_stamp: @card_data['securityStamp'],
        can_be_commander: @card_data.dig('leadershipSkills', 'commander') || false,
        can_be_brawl_commander: @card_data.dig('leadershipSkills', 'brawl') || false,
        can_be_oathbreaker_commander: @card_data.dig('leadershipSkills', 'oathbreaker') || false
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def card_specific_attributes
      {
        original_text: @card_data['originalText'],
        rarity: @card_data['rarity'],
        original_type: @card_data['originalType'],
        edhrec_rank: @card_data['edhrecRank'],
        edhrec_saltiness: @card_data['edhrecSaltiness'],
        converted_mana_cost: @card_data['convertedManaCost'],
        flavor_text: @card_data['flavorText'],
        mana_cost: @card_data['manaCost'],
        mana_value: @card_data['manaValue']
      }
    end
  end
end
