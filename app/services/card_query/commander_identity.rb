#
# resolves a commander name typed into the search bar to that commander's color identity
#
# `commander:prossh` means "legal in a Prossh deck", which is the colour identity subset relation
# ColorPredicate already implements - the only work here is turning a name into letters.
#
# Prefix match rather than exact, because nobody types "Prossh, Skyraider of Kher" into a search bar.
# Restricted to cards that can actually be a commander so a legendary-sounding non-legend cannot
# hijack the term.
#
module CardQuery
  class CommanderIdentity < Service
    def initialize(name:)
      @name = name
    end

    # -> colour letters as a string ("BRG"), '' for a colourless commander, or nil when the name
    # resolves to nothing. nil means the caller should drop the term: failing open beats returning
    # zero rows for a typo.
    def call
      commander = resolve
      return nil unless commander

      MagicCardColorIdent.where(magic_card_id: commander.id).joins(:color).pluck('colors.name').join
    end

    private

    def resolve
      MagicCard.where(can_be_commander: true)
               .where('magic_cards.name ILIKE ?', "#{ActiveRecord::Base.sanitize_sql_like(@name.to_s)}%")
               .order(:name)
               .first
    end
  end
end
