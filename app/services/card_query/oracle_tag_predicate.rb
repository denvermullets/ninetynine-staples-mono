#
# builds the WHERE fragment for an `otag:` / `oracletag:` / `function:` term, Scryfall's own three names
#
# The value resolves to one tag by slug, label or alias. Matching goes through oracle_tag_ancestors, so
# otag:removal finds a card tagged only removal-destroy - Scryfall's umbrella tags carry no direct taggings,
# and without the closure the most obvious searches would return nothing.
#
# A name that resolves to no tag matches no cards. Skipping the term instead (as commander: does) would
# turn a typo into "every card", which is the opposite of what the search claims.
#
# Tags a user added are personal: they only match when that user is searching their own collection, which
# is what viewer_id carries. Everyone else sees Scryfall's tags alone. A nil viewer_id binds as NULL, and
# `user_id = NULL` is never true, so the same statement serves both cases.
#
# Both sides are uuid columns, so unlike CardRolePredicate there is no cast.
#
module CardQuery
  class OracleTagPredicate < Service
    NO_MATCH = ['1 = 0'].freeze

    def initialize(value:, viewer_id: nil)
      @value = value
      @viewer_id = viewer_id
    end

    def call
      tag = OracleTag.enabled.resolve(@value)
      return NO_MATCH if tag.nil?

      [
        "magic_cards.scryfall_oracle_id IN (
           SELECT card_oracle_tags.scryfall_oracle_id FROM card_oracle_tags
           JOIN oracle_tag_ancestors ON oracle_tag_ancestors.descendant_id = card_oracle_tags.oracle_tag_id
           JOIN oracle_tags ON oracle_tags.id = card_oracle_tags.oracle_tag_id
           WHERE oracle_tag_ancestors.ancestor_id = ? AND oracle_tags.disabled = FALSE
             AND (card_oracle_tags.source = 'scryfall' OR card_oracle_tags.user_id = ?)
         )".squish,
        tag.id,
        @viewer_id
      ]
    end
  end
end
