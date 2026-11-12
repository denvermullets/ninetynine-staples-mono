module Commanders
  # Which two-commander pairings land on a target colour identity.
  #
  # Four-colour decks are the reason this exists: there are only a handful of four-colour commanders,
  # but two partners whose identities union to the four colours are just as legal. So for a target
  # identity, a card is kept when its own identity fits inside the target and at least one card it can
  # legally pair with fills in exactly the rest - Thrasios (GU) shows up for WUBG only because a WB or
  # W-and-B-covering partner exists, not merely because GU is inside WUBG.
  #
  # The pairing rules, as printed:
  # - Partner pairs with any other card with plain Partner.
  # - "Partner with X" pairs with the card named X.
  # - "Partner—Survivors" (and every other dash variant) pairs only within the same variant.
  #   "Friends forever" is the older printing of "Partner—Friends forever", so the two share a group.
  # - "Choose a Background" pairs with a Background; Backgrounds are not commanders on their own, so
  #   the pool takes them in by type rather than by can_be_commander.
  # - "Doctor's companion" pairs with a Time Lord Doctor.
  #
  # Rules come off the printed text rather than the keywords table because the keywords table records
  # "Partner—Survivors" as plain "Partner", which would wrongly pair it with Thrasios.
  class PartnerPairs < Service
    PARTNER_WITH = /\APartner with (?<name>.+?)\s*(?:\(|\z)/
    PARTNER_VARIANT = /\APartner\s*[—-]\s*(?<group>.+?)\s*(?:\(|\z)/
    PARTNER = /\APartner\s*(?:\(|\z)/
    FRIENDS_FOREVER = /\AFriends forever\b/i
    CHOOSE_BACKGROUND = /\AChoose a Background\b/i
    DOCTORS_COMPANION = /\ADoctor['’]s companion\b/i

    BACKGROUND_TYPE = /—.*\bBackground\b/
    DOCTOR_TYPE = /—.*\bTime Lord Doctor\b/

    # Only the cards whose text or type could possibly pair, so the identity aggregate runs over a
    # few hundred rows rather than every commander.
    POOL_SQL = <<~SQL.squish.freeze
      magic_cards.text ~* '(^|\\n)(Partner|Friends forever|Choose a Background|Doctor.s companion)'
      OR magic_cards.card_type ~ '—.*Background'
      OR magic_cards.card_type ~ '—.*Time Lord Doctor'
    SQL

    # mask: the target identity as a ColorMask integer, or nil for "any identity a pair can reach".
    def initialize(mask:)
      @mask = mask
    end

    # -> { card name => [names of the cards that complete it] }, only for names with at least one.
    def call
      self.class.pair(pool_rows, @mask)
    end

    # Pure half, so the rules can be specced without building cards: rows are
    # { name:, text:, card_type:, mask: }, one per card name.
    def self.pair(rows, mask)
      cards = classify(rows)

      cards.each_with_object({}) do |card, result|
        next unless fits?(card, mask)

        partners = cards.select { |other| completes_pair?(card, other, mask) }.map { |other| other[:name] }
        result[card[:name]] = partners.sort if partners.any?
      end
    end

    # Rows that hold at least one pairing role, with their roles attached.
    def self.classify(rows)
      rows.map { |row| row.merge(roles: roles_for(row)) }.reject { |card| card[:roles].empty? }
    end

    def self.fits?(card, mask)
      mask.nil? || !card[:mask].anybits?(~mask)
    end

    def self.completes_pair?(card, other, mask)
      return false if other[:name] == card[:name] || !compatible?(card, other)

      mask.nil? || (card[:mask] | other[:mask]) == mask
    end

    # -> Array of [kind, value] pairs. One card can hold more than one (a Background creature that
    # also has Partner, say), and it pairs if any of them match.
    def self.roles_for(row)
      roles = row[:text].to_s.lines.map(&:strip).filter_map { |line| text_role(line) }
      roles << [:background, nil] if row[:card_type].to_s.match?(BACKGROUND_TYPE)
      roles << [:doctor, nil] if row[:card_type].to_s.match?(DOCTOR_TYPE)
      roles.uniq
    end

    def self.text_role(line)
      if (match = line.match(PARTNER_WITH)) then [:partner_with, match[:name]]
      elsif (match = line.match(PARTNER_VARIANT)) then [:group, normalize_group(match[:group])]
      elsif line.match?(PARTNER) then [:group, 'partner']
      elsif line.match?(FRIENDS_FOREVER) then [:group, 'friends forever']
      elsif line.match?(CHOOSE_BACKGROUND) then [:chooses_background, nil]
      elsif line.match?(DOCTORS_COMPANION) then [:companion, nil]
      end
    end

    def self.normalize_group(group)
      group.downcase.squish
    end

    # The role pairs that match on kind alone; groups and Partner with also compare values.
    COMPLEMENTS = [%i[chooses_background background], %i[background chooses_background],
                   %i[companion doctor], %i[doctor companion]].freeze

    def self.compatible?(card, other)
      card[:roles].product(other[:roles]).any? do |(kind, value), (other_kind, other_value)|
        case [kind, other_kind]
        when %i[group group] then value == other_value
        # either side naming the other is enough - one printing's text can be shorter than the other's
        when %i[partner_with partner_with] then value == other[:name] || other_value == card[:name]
        else COMPLEMENTS.include?([kind, other_kind])
        end
      end
    end

    private

    # Cached because the pool only changes when a card import runs, and the regex scan plus the
    # identity aggregate is most of the cost of a /commanders request with the partner filter on.
    def pool_rows
      Rails.cache.fetch('commanders/partner_pool', expires_in: 1.hour) { load_pool_rows }
    end

    def load_pool_rows
      MagicCard.where(is_token: false)
               .where("magic_cards.card_side IS NULL OR magic_cards.card_side != 'b'")
               .where(POOL_SQL)
               .commander_legal
               .left_joins(magic_card_color_idents: :color)
               .group('magic_cards.name', 'magic_cards.text', 'magic_cards.card_type')
               .pluck('magic_cards.name', 'magic_cards.text', 'magic_cards.card_type',
                      Arel.sql(ColorMask::IDENTITY_MASK))
               .uniq(&:first)
               .map { |name, text, card_type, mask| { name: name, text: text, card_type: card_type, mask: mask } }
    end
  end
end
