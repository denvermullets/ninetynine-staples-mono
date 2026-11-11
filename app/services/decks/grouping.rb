module Decks
  # -> [Group, ...] for the decks index. Groups come out in a fixed, meaningful order (tags A-Z, colour
  # identities by colour count then WUBRG, brackets 1-5), and the catch-all group always comes last.
  # Decks keep the order they were handed in, so the page's sort still applies inside each group.
  #
  # Grouping by tag is the one non-partition: a deck with two tags shows up under both, because
  # that is what a tag means. Every other option puts each deck in exactly one group.
  class Grouping < Service
    OPTIONS = {
      'none' => 'None',
      'tag' => 'Tag',
      'color' => 'Color Identity',
      'bracket' => 'Bracket',
      'format' => 'Format'
    }.freeze

    FORMAT_LABELS = { 'commander_deck' => 'Commander', 'deck' => 'Deck' }.freeze

    Group = Data.define(:key, :label, :decks, :tag, :color_identity) do
      def initialize(key:, label:, decks:, tag: nil, color_identity: nil)
        super
      end
    end

    def initialize(decks:, by:, color_identities: {})
      @decks = decks.to_a
      @by = by
      @color_identities = color_identities
    end

    def call
      return [] if @decks.empty?

      case @by
      when 'tag' then by_tag
      when 'color' then by_color
      when 'bracket' then by_bracket
      when 'format' then by_format
      else [Group.new(key: 'all', label: 'All Decks', decks: @decks)]
      end
    end

    private

    def by_tag
      tags = @decks.flat_map(&:tags).uniq.sort_by { |tag| tag.name.downcase }
      groups = tags.map do |tag|
        Group.new(key: "tag-#{tag.id}", label: tag.name, tag: tag,
                  decks: @decks.select { |deck| deck.tags.include?(tag) })
      end

      groups + catch_all('Untagged', @decks.select { |deck| deck.tags.empty? })
    end

    def by_color
      known, unknown = @decks.partition { |deck| @color_identities[deck.id].present? }
      groups = known.group_by { |deck| @color_identities[deck.id] }
                    .sort_by { |letters, _| color_order(letters) }
                    .map do |letters, decks|
                      Group.new(key: "color-#{letters}", label: letters, color_identity: letters, decks: decks)
                    end

      groups + catch_all('No cards yet', unknown)
    end

    def by_bracket
      bracketed, unbracketed = @decks.partition(&:bracket_level)
      groups = bracketed.group_by(&:bracket_level).sort.map do |level, decks|
        Group.new(key: "bracket-#{level}", label: "Bracket #{level}", decks: decks)
      end

      groups + catch_all('No bracket', unbracketed)
    end

    def by_format
      @decks.group_by(&:collection_type)
            .sort_by { |type, _| [type == 'commander_deck' ? 0 : 1, type.to_s] }
            .map do |type, decks|
              Group.new(key: "format-#{type}", label: format_label(type), decks: decks)
            end
    end

    def catch_all(label, decks)
      return [] if decks.empty?

      [Group.new(key: 'other', label: label, decks: decks)]
    end

    # Colourless first, then mono, two-colour and so on; ties broken by WUBRG position of each letter.
    def color_order(letters)
      return [0, []] if letters == 'C'

      [letters.length, letters.chars.map { |letter| Commanders::ColorMask::BITS.keys.index(letter) }]
    end

    def format_label(type)
      FORMAT_LABELS.fetch(type) { type.to_s.delete_suffix('_deck').humanize }
    end
  end
end
