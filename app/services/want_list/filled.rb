# The wants that a batch of new copies has just filled: rows that were short before the copies
# landed and hold enough now. Asked after the copies are saved, so "now" is the database and
# "before" is now minus what was added.
#
# `additions` is { magic_card => { quantity:, foil_quantity: } } - the real copies added, proxies
# never count. A copy only counts toward a want in the finish it asks for, the same rule
# WantList::List uses for the "Owned" column, and ownership is counted across every collection the
# user has, because it is the owner being told.
#
# A want that was already filled is left out, so topping up a card the user has enough of does not
# ask again. Nothing is removed here: the caller offers the removal and the user decides.
module WantList
  class Filled < Service
    def initialize(user:, additions:)
      @user = user
      @additions = normalize(additions)
    end

    def call
      return [] if @user.nil? || @additions.empty?

      candidates.select { |item| filled?(item) }
    end

    private

    # front faces, since that is what wants point at, and only the copies that went up
    def normalize(additions)
      totals = Hash.new { |hash, card| hash[card] = { quantity: 0, foil_quantity: 0 } }

      additions.each do |card, added|
        quantity = [added[:quantity].to_i, 0].max
        foil_quantity = [added[:foil_quantity].to_i, 0].max
        next if quantity.zero? && foil_quantity.zero?

        totals[card.front_face][:quantity] += quantity
        totals[card.front_face][:foil_quantity] += foil_quantity
      end

      totals
    end

    def candidates
      cards = @additions.keys
      oracle_ids = cards.filter_map(&:scryfall_oracle_id)
      wants = @user.want_list_items.for_printing(cards.map(&:id))
      wants = wants.or(@user.want_list_items.any_printing.for_oracle(oracle_ids)) if oracle_ids.any?

      wants.select('want_list_items.*', owned_select).includes(:magic_card).order(:id)
    end

    def owned_select
      WantListItem.sanitize_sql_array(
        ["(#{List::OWNED_SQL}) AS owned_quantity", { collection_ids: @user.collection_ids }]
      )
    end

    def filled?(item)
      owned = item.owned_quantity.to_i
      owned >= item.quantity && owned - added_toward(item) < item.quantity
    end

    def added_toward(item)
      @additions.sum do |card, added|
        next 0 unless item.satisfied_by?(card)

        case item.foil_preference
        when 'foil' then added[:foil_quantity].to_i
        when 'non_foil' then added[:quantity].to_i
        else added[:quantity].to_i + added[:foil_quantity].to_i
        end
      end
    end
  end
end
