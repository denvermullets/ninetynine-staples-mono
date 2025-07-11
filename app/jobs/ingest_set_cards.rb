require 'open-uri'

# rubocop:disable Metrics/ClassLength
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Metrics/MethodLength
class IngestSetCards < ApplicationJob
  def perform(set)
    puts "loading #{set['name']} - #{set['code']}.json from mtgjson.com"
    source = URI.open("https://mtgjson.com/api/v5/#{set['code']}.json")
    puts "completed loading #{set['code']}.json from mtgjson.com"
    all_info = JSON.parse(source.read)['data']

    puts "opening up #{set['name']}"
    boxset = Boxset.find_by(code: set['code'])

    boxset.update(
      code: set['code'],
      name: set['name'],
      release_date: set['releaseDate'],
      base_set_size: set['baseSetSize'],
      total_set_size: set['totalSetSize'],
      set_type: set['type']
    )

    all_info['cards'].each do |card|
      # we want to make sure we only add paper cards now that there's digital only
      next unless card['availability'].include?('paper')

      puts "working on card #{card['name']}"
      magic_card = create_magic_card(boxset, card)
      magic_card.boxset.update(valid_cards: true)

      # bleeding edge sets don't always have artist info loaded
      if card['artist'].present?
        artist = Artist.where('LOWER(name) = LOWER(?)', card['artist']).first || Artist.create(name: card['artist'])
        MagicCardArtist.find_by(artist:, magic_card:) || MagicCardArtist.create(artist:, magic_card:)
      else
        puts "**** PROBLEM w/ARTIST on card #{card['name']}"
      end

      card['subtypes'].each { |sub_type| create_sub_type(magic_card, sub_type) }
      card['supertypes'].each { |super_type| create_supertype(magic_card, super_type) }
      card['types'].each { |card_type| create_type(magic_card, card_type) }
      card['colors'].each { |color| create_color(magic_card, color) }
      card['colorIdentity'].each { |color| create_color_ident(magic_card, color) }
      # card["rulings"].each { |ruling| create_ruling(magic_card, ruling) }

      card['keywords'].each { |keyword| create_keywords(magic_card, keyword) } if card.key?('keywords')
    end
  end

  def create_magic_card(boxset, card)
    existing_card = MagicCard.find_by(card_uuid: card['uuid'])

    card_obj = {
      boxset:, name: card['name'], text: card['text'], original_text: card['originalText'],
      power: card['power'], toughness: card['toughness'], rarity: card['rarity'], card_type: card['type'],
      original_type: card['originalType'], edhrec_rank: card['edhrecRank'], has_foil: card['hasFoil'],
      has_non_foil: card['hasNonFoil'], border_color: card['borderColor'],
      converted_mana_cost: card['convertedManaCost'], flavor_text: card['flavorText'],
      frame_version: card['frameVersion'], is_reprint: card['isReprint'], card_number: card['number'],
      identifiers: card['identifiers'], card_uuid: card['uuid'], mana_cost: card['manaCost'],
      mana_value: card['manaValue'], face_name: card['faceName'], card_side: card['side'],
      other_face_uuid: card.key?('otherFaceIds') ? card['otherFaceIds'].join(',') : nil
    }

    if existing_card
      empty_image = existing_card.image_large.nil? || existing_card.image_medium.nil? ||
                    existing_card.image_small.nil? || existing_card.art_crop.nil? ||
                    existing_card.image_updated_at < 90.days.ago

      if empty_image || error_image?(existing_card)
        images = scryfall_images(card)
        card_obj[:image_large] = images[:large]
        card_obj[:image_medium] = images[:normal]
        card_obj[:image_small] = images[:small]
        card_obj[:art_crop] = images[:art_crop]
        card_obj[:image_updated_at] = Time.now
      end

      existing_card.update(card_obj)
      existing_card
    else
      puts "creating new card #{card['name']}"
      images = scryfall_images(card)
      card_obj[:image_large] = images[:large]
      card_obj[:image_medium] = images[:normal]
      card_obj[:image_small] = images[:small]
      card_obj[:art_crop] = images[:art_crop]
      card_obj[:image_updated_at] = Time.now
      card_obj[:normal_price] = 0
      card_obj[:foil_price] = 0

      MagicCard.create(card_obj)
    end
  end

  def error_image?(existing_card)
    error = 'https://errors.scryfall.com/soon.jpg'

    existing_card.image_large == error ||
      existing_card.image_medium == error ||
      existing_card.image_small == error
  end

  def scryfall_images(card)
    puts "looking up images for #{card['name']}"
    scryfall = card['identifiers']['scryfallId'].to_s
    res = HTTParty.get("https://api.scryfall.com/cards/#{scryfall}")

    if res&.key?('image_uris') && res['image_uris'].key?('large')
      large = res['image_uris']['large']
      normal = res['image_uris']['normal']
      small = res['image_uris']['small']
      art_crop = res['image_uris']['art_crop']
    elsif res && card['otherFaceIds'] && res['card_faces'][0].key?('image_uris')
      large = res['card_faces'][card['side'] == 'a' ? 0 : 1]['image_uris']['large']
      normal = res['card_faces'][card['side'] == 'a' ? 0 : 1]['image_uris']['normal']
      small = res['card_faces'][card['side'] == 'a' ? 0 : 1]['image_uris']['small']
      art_crop = res['card_faces'][card['side'] == 'a' ? 0 : 1]['image_uris']['art_crop']
    end

    # respecting scryfall rate limit requests
    sleep 0.350

    { small:, normal:, large:, art_crop: }
  end

  def create_sub_type(magic_card, sub_type)
    find_subtype = SubType.find_by(name: sub_type) || SubType.create(name: sub_type)
    MagicCardSubType.find_by(magic_card:,
                             sub_type: find_subtype) || MagicCardSubType.create(
                               magic_card:, sub_type: find_subtype
                             )
  end

  def create_supertype(magic_card, super_type)
    supertype = SuperType.find_by(name: super_type) || SuperType.create(name: super_type)
    MagicCardSuperType.find_by(magic_card:,
                               super_type: supertype) || MagicCardSuperType.create(
                                 magic_card:, super_type: supertype
                               )
  end

  def create_type(magic_card, card_type)
    cardtype = CardType.find_by(name: card_type) || CardType.create(name: card_type)
    MagicCardType.find_by(magic_card:, card_type: cardtype) || MagicCardType.create(magic_card:, card_type: cardtype)
  end

  def create_color(magic_card, color)
    card_color = Color.find_by(name: color) || Color.create(name: color)
    MagicCardColor.find_by(color: card_color, magic_card:) || MagicCardColor.create(color: card_color, magic_card:)
  end

  def create_color_ident(magic_card, color)
    card_color = Color.find_by(name: color) || Color.create(name: color)
    MagicCardColorIdent.find_by(color: card_color,
                                magic_card:) || MagicCardColorIdent.create(
                                  color: card_color, magic_card:
                                )
  end

  def create_ruling(card, ruling)
    rule = Ruling.create(ruling_date: ruling['date'], ruling: ruling['text'])
    MagicCardRuling.create(ruling: rule, magic_card: card)
  end

  def create_keywords(magic_card, word)
    keyword = Keyword.find_by(keyword: word) || Keyword.create(keyword: word)
    MagicCardKeyword.find_by(magic_card:, keyword:) || MagicCardKeyword.create(magic_card:, keyword:)
  end
end

# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/PerceivedComplexity
# rubocop:enable Metrics/MethodLength
