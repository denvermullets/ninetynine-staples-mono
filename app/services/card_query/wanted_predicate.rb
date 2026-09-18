#
# builds the WHERE fragment for a `wanted:` term - the printings the searcher's want list matches
#
# The SQL twin of WantListItem.matching: a want always matches the printing it points at, and an
# any-printing want also matches everything sharing its oracle id. Wants are anchored to the front face,
# so a back face is read through other_face_uuid, the same way `matching` reads it through front_face.
#
# The want list is the searcher's, not the collection owner's: wanted:true on someone else's trade list
# is the point of the keyword. That is why this takes wanter_id rather than Builder's viewer_id, which is
# only set when somebody searches their own collection.
#
# Nobody signed in wants nothing, so wanted:true matches no cards and wanted:false matches all of them.
#
# A subquery rather than a join for the usual Builder reason - the relation may already be grouped with
# SUM aggregates, and a join would fan the rows out. Both oracle id columns are uuid, so unlike
# CardRolePredicate there is no cast.
#
# Returns an array ready to splat into `where`: [sql, *binds].
#
module CardQuery
  class WantedPredicate < Service
    NO_MATCH = '1 = 0'.freeze

    WANTED = "(
      magic_cards.id IN (
        SELECT want_list_items.magic_card_id FROM want_list_items WHERE want_list_items.user_id = :wanter_id
      )
      OR magic_cards.scryfall_oracle_id IN (
        SELECT want_list_items.scryfall_oracle_id FROM want_list_items
        WHERE want_list_items.user_id = :wanter_id AND want_list_items.any_printing = TRUE
          AND want_list_items.scryfall_oracle_id IS NOT NULL
      )
      OR (magic_cards.card_side = 'b' AND magic_cards.other_face_uuid IN (
        SELECT front_faces.card_uuid FROM magic_cards front_faces
        INNER JOIN want_list_items ON want_list_items.magic_card_id = front_faces.id
        WHERE want_list_items.user_id = :wanter_id
      ))
    )".squish.freeze

    def initialize(value:, wanter_id: nil)
      @value = value
      @wanter_id = wanter_id
    end

    def call
      sql = @wanter_id.nil? ? NO_MATCH : WANTED
      sql = "NOT COALESCE((#{sql}), FALSE)" unless truthy?

      @wanter_id.nil? ? [sql] : [sql, { wanter_id: @wanter_id }]
    end

    private

    def truthy?
      %w[true yes].include?(@value.to_s.downcase)
    end
  end
end
