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

    # rubocop:disable-next Metrics/MethodLength
    def base_attributes
      {
        boxset: @boxset,
        name: @card_data['name'],
        text: @card_data['text'],
        power: @card_data['power'],
        toughness: @card_data['toughness'],
        card_type: @card_data['type'],
        border_color: @card_data['borderColor'],
        frame_version: @card_data['frameVersion'],
        is_reprint: @card_data['isReprint'],
        card_number: @card_data['number'],
        scryfall_oracle_id: @card_data.dig('identifiers', 'scryfallOracleId'),
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

    # The alternate name on this printing, if it has one - "Balin's Tomb" on an LTC Ancient Tomb. Read
    # per face first, so each side of a double-faced card keeps its own.
    #
    # mtgjson is not consistent about where it puts these: most are flavorName, but some Secret Lair
    # drops (Stranger Things, the D&D movie) only have printedName. printedName is on plenty of ordinary
    # cards too, repeating the real name, so it only counts when it says something different.
    def flavor_name
      flavor = @card_data['faceFlavorName'] || @card_data['flavorName']
      return flavor if flavor.present?

      printed = @card_data['facePrintedName'] || @card_data['printedName']
      printed if printed.present? && printed != (@card_data['faceName'] || @card_data['name'])
    end

    # Tokens are excluded from all of this, which is why is_reserved sits here rather than next to
    # is_reprint above: nothing on the Reserved List is a token, so a token has no answer to give.
    def card_specific_attributes
      {
        # mtgjson omits isReserved entirely when it is false, so the key is either true or absent -
        # reading it straight through would write nil into a NOT NULL column
        is_reserved: @card_data['isReserved'] || false,
        original_text: @card_data['originalText'],
        rarity: @card_data['rarity'],
        original_type: @card_data['originalType'],
        edhrec_rank: @card_data['edhrecRank'],
        edhrec_saltiness: @card_data['edhrecSaltiness'],
        converted_mana_cost: @card_data['convertedManaCost'],
        flavor_name: flavor_name,
        flavor_text: @card_data['flavorText'],
        mana_cost: @card_data['manaCost'],
        mana_value: @card_data['manaValue']
      }
    end
  end
end
