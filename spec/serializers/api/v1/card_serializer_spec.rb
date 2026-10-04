require 'rails_helper'

RSpec.describe Api::V1::CardSerializer do
  let(:boxset) { create(:boxset, code: 'CMM', name: 'Commander Masters') }
  let(:commander) { Legality.find_or_create_by!(name: 'commander') }

  # one magic_cards row with its type, color and keyword join rows, the way ingestion writes them. Join
  # rows are passed as supertypes:, types:, subtypes:, colors:, identity: (defaults to colors) and keywords:
  def card_row(**attrs)
    joins = attrs.extract!(:supertypes, :types, :subtypes, :colors, :identity, :keywords)
    card = create(:magic_card, boxset: boxset, card_uuid: SecureRandom.uuid, scryfall_oracle_id: SecureRandom.uuid,
                               layout: 'normal', **attrs)
    add_join_rows(card, joins)
    card
  end

  let(:join_rows) do
    {
      supertypes: [:super_types, ->(name) { SuperType.find_or_create_by!(name: name) }],
      types: [:card_types, ->(name) { CardType.find_or_create_by!(name: name) }],
      subtypes: [:sub_types, ->(name) { SubType.find_or_create_by!(name: name) }],
      colors: [:colors, ->(name) { Color.find_by(name: name) || FactoryBot.create(:color, name: name) }],
      identity: [:color_identities, ->(name) { Color.find_by(name: name) || FactoryBot.create(:color, name: name) }],
      keywords: [:keywords, ->(name) { Keyword.find_or_create_by!(keyword: name) }]
    }
  end

  def add_join_rows(card, joins)
    joins[:identity] = joins[:colors] unless joins.key?(:identity)
    joins.each do |key, names|
      association, find = join_rows.fetch(key)
      Array(names).each { |name| card.public_send(association) << find.call(name) }
    end
  end

  # links the rows the way ingestion does: each face names every other face of the printing
  def link_faces(*faces)
    faces.each do |face|
      face.update!(other_face_uuid: (faces - [face]).map(&:card_uuid).join(','),
                   scryfall_oracle_id: faces.first.scryfall_oracle_id)
    end
  end

  def legal_in_commander(card, status = 'Legal')
    MagicCardLegality.create!(magic_card: card, legality: commander, status: status)
    MagicCardLegality.create!(magic_card: card, legality: Legality.find_or_create_by!(name: 'modern'), status: 'Banned')
  end

  def serialize(card, **)
    described_class.new(card, **).as_json
  end

  describe 'a normal creature' do
    let(:card) do
      card_row(name: 'Sythis, Harvest\'s Hand', mana_cost: '{G}{W}', mana_value: 2, rarity: 'rare', card_number: '123',
               card_type: 'Legendary Enchantment Creature — Nymph', supertypes: ['Legendary'],
               types: %w[Creature Enchantment], subtypes: ['Nymph'], text: 'Whenever you cast an enchantment spell...',
               power: '1', toughness: '2', colors: %w[W G], keywords: %w[Vigilance Lifelink], can_be_commander: true,
               edhrec_rank: 1234, image_small: 'https://cards.scryfall.io/small/front/s.jpg',
               image_medium: 'https://cards.scryfall.io/normal/front/s.jpg',
               image_large: 'https://cards.scryfall.io/large/front/s.jpg', art_crop: 'https://errors.scryfall.com/soon.jpg')
    end

    before { legal_in_commander(card) }

    it 'serializes the card-level fields' do
      expect(serialize(card)).to include(
        card_uuid: card.card_uuid, oracle_id: card.scryfall_oracle_id, name: 'Sythis, Harvest\'s Hand',
        layout: 'normal', set: { code: 'CMM', name: 'Commander Masters', card_number: '123' }, rarity: 'rare',
        is_token: false, can_be_commander: true, commander_legality: 'Legal', color_identity: %w[W G],
        edhrec_rank: 1234
      )
    end

    it 'serializes a single face with types in type-line order and colors in WUBRG order' do
      faces = serialize(card)[:faces]

      expect(faces.size).to eq(1)
      expect(faces.first).to include(
        side: 'a', name: 'Sythis, Harvest\'s Hand', mana_cost: '{G}{W}', mana_value: 2.0,
        type_line: 'Legendary Enchantment Creature — Nymph', supertypes: ['Legendary'],
        types: %w[Enchantment Creature], subtypes: ['Nymph'], oracle_text: 'Whenever you cast an enchantment spell...',
        power: '1', toughness: '2', loyalty: nil, defense: nil, colors: %w[W G], keywords: %w[Lifelink Vigilance]
      )
    end

    it 'exposes image_medium as normal and nulls the not-yet-released placeholder' do
      expect(serialize(card)[:faces].first[:images]).to eq(
        small: 'https://cards.scryfall.io/small/front/s.jpg', normal: 'https://cards.scryfall.io/normal/front/s.jpg',
        large: 'https://cards.scryfall.io/large/front/s.jpg', art_crop: nil
      )
    end

    it 'leaves rulings out unless asked, and lists them oldest first when asked' do
      newer = Ruling.create!(ruling: 'Second.', ruling_date: Date.new(2024, 2, 1))
      older = Ruling.create!(ruling: 'First.', ruling_date: Date.new(2023, 1, 1))
      card.rulings << newer << older

      expect(serialize(card)).not_to have_key(:rulings)
      expect(serialize(card, rulings: true)[:rulings]).to eq(
        [{ date: '2023-01-01', text: 'First.' }, { date: '2024-02-01', text: 'Second.' }]
      )
    end
  end

  it 'serializes a planeswalker with no power or toughness' do
    card = card_row(name: 'Karn Liberated', mana_cost: '{7}', mana_value: 7, card_type: 'Legendary Planeswalker — Karn',
                    supertypes: ['Legendary'], types: ['Planeswalker'], subtypes: ['Karn'], text: '[+4]: ...')

    expect(serialize(card)[:faces].first).to include(
      types: ['Planeswalker'], subtypes: ['Karn'], power: nil, toughness: nil, loyalty: nil, colors: []
    )
  end

  describe 'a transform double-faced card' do
    let(:front) do
      card_row(name: 'Delver of Secrets // Insectile Aberration', face_name: 'Delver of Secrets', card_side: 'a',
               layout: 'transform', mana_cost: '{U}', mana_value: 1, card_type: 'Creature — Human Wizard',
               types: ['Creature'], subtypes: %w[Human Wizard], power: '1', toughness: '1', colors: ['U'],
               image_medium: 'https://cards.scryfall.io/normal/front/d.jpg')
    end
    let(:back) do
      card_row(name: 'Delver of Secrets // Insectile Aberration', face_name: 'Insectile Aberration', card_side: 'b',
               layout: 'transform', mana_value: 1, card_type: 'Creature — Human Insect', types: ['Creature'],
               subtypes: %w[Human Insect], power: '3', toughness: '2', colors: ['U'], keywords: ['Flying'],
               image_medium: 'https://cards.scryfall.io/normal/back/d.jpg')
    end

    before do
      link_faces(front, back)
      legal_in_commander(front)
    end

    it 'nests both faces under the front face, ordered by side' do
      json = serialize(front)

      expect(json).to include(card_uuid: front.card_uuid, name: 'Delver of Secrets // Insectile Aberration',
                              layout: 'transform', commander_legality: 'Legal')
      expect(json[:faces].map { |f| [f[:side], f[:name], f[:mana_cost], f[:power]] }).to eq(
        [['a', 'Delver of Secrets', '{U}', '1'], ['b', 'Insectile Aberration', nil, '3']]
      )
      expect(json[:faces].map { |f| f[:images][:normal] }).to eq(
        ['https://cards.scryfall.io/normal/front/d.jpg', 'https://cards.scryfall.io/normal/back/d.jpg']
      )
      expect(json[:faces].last[:keywords]).to eq(['Flying'])
    end

    it 'serializes the same card when handed the back face' do
      expect(serialize(back)).to eq(serialize(front))
    end
  end

  it 'serializes a modal double-faced card with a castable back face' do
    front = card_row(name: 'Halvar, God of Battle // Sword of the Realms', face_name: 'Halvar, God of Battle',
                     card_side: 'a', layout: 'modal_dfc', mana_cost: '{2}{W}{W}', card_type: 'Legendary Creature — God',
                     supertypes: ['Legendary'], types: ['Creature'], subtypes: ['God'], colors: ['W'])
    back = card_row(name: 'Halvar, God of Battle // Sword of the Realms', face_name: 'Sword of the Realms',
                    card_side: 'b', layout: 'modal_dfc', mana_cost: '{1}{W}',
                    card_type: 'Legendary Artifact — Equipment', supertypes: ['Legendary'], types: ['Artifact'],
                    subtypes: ['Equipment'], colors: ['W'])
    link_faces(front, back)

    expect(serialize(front)[:faces].map { |f| f.slice(:side, :name, :mana_cost, :types, :subtypes) }).to eq(
      [{ side: 'a', name: 'Halvar, God of Battle', mana_cost: '{2}{W}{W}', types: ['Creature'], subtypes: ['God'] },
       { side: 'b', name: 'Sword of the Realms', mana_cost: '{1}{W}', types: ['Artifact'], subtypes: ['Equipment'] }]
    )
  end

  it 'serializes an adventure as the creature face and the adventure face' do
    front = card_row(name: 'Bonecrusher Giant // Stomp', face_name: 'Bonecrusher Giant', card_side: 'a',
                     layout: 'adventure', mana_cost: '{2}{R}', mana_value: 3, card_type: 'Creature — Giant',
                     types: ['Creature'], subtypes: ['Giant'], power: '4', toughness: '3', colors: ['R'])
    back = card_row(name: 'Bonecrusher Giant // Stomp', face_name: 'Stomp', card_side: 'b', layout: 'adventure',
                    mana_cost: '{1}{R}', mana_value: 3, card_type: 'Instant — Adventure', types: ['Instant'],
                    subtypes: ['Adventure'], colors: ['R'])
    link_faces(front, back)

    expect(serialize(front)[:faces].map { |f| f.slice(:name, :mana_cost, :types, :subtypes, :power) }).to eq(
      [{ name: 'Bonecrusher Giant', mana_cost: '{2}{R}', types: ['Creature'], subtypes: ['Giant'], power: '4' },
       { name: 'Stomp', mana_cost: '{1}{R}', types: ['Instant'], subtypes: ['Adventure'], power: nil }]
    )
  end

  it 'serializes a split card with each half keeping its own cost and colors' do
    fire = card_row(name: 'Fire // Ice', face_name: 'Fire', card_side: 'a', layout: 'split', mana_cost: '{1}{R}',
                    mana_value: 4, card_type: 'Instant', types: ['Instant'], colors: ['R'], identity: %w[U R])
    ice = card_row(name: 'Fire // Ice', face_name: 'Ice', card_side: 'b', layout: 'split', mana_cost: '{1}{U}',
                   mana_value: 4, card_type: 'Instant', types: ['Instant'], colors: ['U'], identity: %w[U R])
    link_faces(fire, ice)

    json = serialize(fire)

    expect(json[:color_identity]).to eq(%w[U R])
    expect(json[:faces].map { |f| f.slice(:name, :mana_cost, :mana_value, :colors) }).to eq(
      [{ name: 'Fire', mana_cost: '{1}{R}', mana_value: 4.0, colors: ['R'] },
       { name: 'Ice', mana_cost: '{1}{U}', mana_value: 4.0, colors: ['U'] }]
    )
  end

  it 'serializes a token, which has no side and no commander legality' do
    token = card_row(name: 'Eldrazi Spawn', layout: 'token', is_token: true,
                     card_type: 'Token Creature — Eldrazi Spawn', types: %w[Token Creature],
                     subtypes: %w[Eldrazi Spawn], power: '0', toughness: '1')

    json = serialize(token)

    expect(json).to include(is_token: true, layout: 'token', commander_legality: nil)
    expect(json[:faces].sole).to include(side: 'a', name: 'Eldrazi Spawn', types: %w[Token Creature],
                                         subtypes: %w[Eldrazi Spawn])
  end

  it 'serializes a meld result on its own rather than as a back face of the cards that meld into it' do
    engine = card_row(name: 'Phyrexian Dragon Engine // Mishra, Lost to Phyrexia', face_name: 'Phyrexian Dragon Engine',
                      card_side: 'a', layout: 'meld')
    mishra_card = card_row(name: 'Mishra, Claimed by Gix // Mishra, Lost to Phyrexia',
                           face_name: 'Mishra, Claimed by Gix', card_side: 'a', layout: 'meld')
    result = card_row(name: 'Mishra, Lost to Phyrexia', face_name: 'Mishra, Lost to Phyrexia', card_side: 'b',
                      layout: 'meld')
    engine.update!(other_face_uuid: result.card_uuid)
    mishra_card.update!(other_face_uuid: result.card_uuid)
    result.update!(other_face_uuid: [engine.card_uuid, mishra_card.card_uuid].join(','))

    expect(serialize(result)).to include(card_uuid: result.card_uuid, name: 'Mishra, Lost to Phyrexia')
    expect(serialize(result)[:faces].map { |f| f[:name] }).to eq(['Mishra, Lost to Phyrexia'])
    expect(serialize(engine)[:faces].map { |f| f[:name] })
      .to eq(['Phyrexian Dragon Engine', 'Mishra, Lost to Phyrexia'])
  end

  describe '.many' do
    def query_count
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION])
      end
      yield
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    # a 100-card deck: mostly single-faced cards plus a handful of double-faced ones, each row with type,
    # color, keyword, legality and ruling rows to load
    let!(:deck_ids) do
      ruling = Ruling.create!(ruling: 'A ruling.', ruling_date: Date.new(2024, 1, 1))
      singles = Array.new(90) do |i|
        card_row(name: "Card #{i}", card_type: 'Legendary Creature — Elf Druid', supertypes: ['Legendary'],
                 types: ['Creature'], subtypes: %w[Elf Druid], colors: ['G'], keywords: ['Reach']).tap do |card|
          legal_in_commander(card)
          card.rulings << ruling
        end
      end
      fronts = Array.new(10) do |i|
        front = card_row(name: "DFC #{i}", card_side: 'a', layout: 'transform', types: ['Creature'], colors: ['U'])
        back = card_row(name: "DFC #{i}", card_side: 'b', layout: 'transform', types: ['Creature'], colors: ['U'])
        link_faces(front, back)
        legal_in_commander(front)
        front
      end
      (singles + fronts).map(&:id)
    end

    it 'serializes every card in the order given' do
      json = described_class.many(MagicCard.where(id: deck_ids).order(:id))

      expect(json.map { |c| c[:card_uuid] }).to eq(MagicCard.where(id: deck_ids).order(:id).pluck(:card_uuid))
      expect(json.count { |c| c[:faces].size == 2 }).to eq(10)
    end

    it 'serializes a 100-card deck in about 15 queries, rulings included' do
      expect(query_count { described_class.many(MagicCard.where(id: deck_ids)).to_json }).to be <= 15
      expect(query_count { described_class.many(MagicCard.where(id: deck_ids), rulings: true).to_json }).to be <= 17
    end

    # one single-faced and one double-faced card already touch every association, so a hundred cost the same
    it 'runs the same number of queries for two cards as for a hundred' do
      two = query_count { described_class.many(MagicCard.where(id: deck_ids.values_at(0, -1))).to_json }
      hundred = query_count { described_class.many(MagicCard.where(id: deck_ids)).to_json }

      expect(hundred).to eq(two)
    end

    it 'returns an empty list without querying for faces when given no cards' do
      expect(query_count { expect(described_class.many([])).to eq([]) }).to eq(0)
    end
  end

  describe 'MagicCard.api_preload' do
    it 'loads every association the serializer reads' do
      card = card_row(name: 'Preloaded', types: ['Creature'])
      loaded = MagicCard.api_preload.find(card.id)

      expect(MagicCard::API_PRELOADS.map { |name| loaded.association(name).loaded? }).to all(be(true))
    end
  end
end
