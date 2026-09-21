# Turns one side of a deck comparison - a pasted decklist, or one of the viewer's own decks - into a
# single hash shape, so the diff never has to care where a side came from.
#
# This is also where authorization lives, as a service for the same reason WantList::Access is one:
# the rule is the part worth testing, and a request spec that gets past it renders a layout CI cannot
# build. The page is public, so `viewer` may be nil, and the only decks a side can name are the
# viewer's own. Every way of not having one - logged out, someone else's deck, a binder, an id that
# does not exist - answers with the same error, so a deck's existence never leaks.
#
# A side nobody filled in (no source, or a paste with no text) is `blank`, not an error: the form
# re-submits on every grouping change, often with one side still empty.
module DeckComparison
  class LoadSide < Service
    EMPTY = { source: 'none', deck_name: nil, blank: true, error: nil,
              cards: [], ambiguous: [], unresolved: [] }.freeze

    def initialize(viewer:, source:, text:, deck_id:, label:)
      @viewer = viewer
      @source = source
      @text = text.to_s
      @deck_id = deck_id
      @label = label
    end

    def call
      EMPTY.merge(label: @label, **side)
    end

    private

    def side
      case @source
      when 'deck' then FromDeck.call(viewer: @viewer, deck_id: @deck_id).merge(source: 'deck', blank: false)
      when 'paste' then paste_side
      else {}
      end
    end

    def paste_side
      return {} if @text.blank?

      FromPaste.call(text: @text).merge(source: 'paste', blank: false)
    end
  end
end
