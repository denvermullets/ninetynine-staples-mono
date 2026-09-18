# adds a card to a user's want list, or edits the row that already covers it
#
# Adding is forgiving rather than strict: the row for this exact printing is reused, and an
# "any printing" add lands on the any-printing row the user already has for the card, because the
# unique indexes allow one of each and a second click should edit, not fail. Pass `item:` to edit a
# known row. Quantity is clamped to at least 1 - removing a want is WantList::Remove's job.
module WantList
  class Upsert < Service
    def initialize(user:, magic_card: nil, item: nil, attributes: {})
      @user = user
      @magic_card = magic_card&.front_face
      @item = item
      @attributes = attributes.to_h.symbolize_keys
    end

    def call
      item = @item || existing_item || @user.want_list_items.new(magic_card: @magic_card)
      created = item.new_record?
      item.assign_attributes(cleaned_attributes(item))

      if item.save
        { success: true, item:, created:, name: item.magic_card.name }
      else
        { success: false, error: error_message(item) }
      end
    rescue ActiveRecord::RecordNotUnique
      { success: false, error: 'That card is already on your want list.' }
    end

    private

    def existing_item
      items = @user.want_list_items
      exact = items.for_printing(@magic_card.id).first
      return exact if exact
      return nil unless any_printing?(nil) && @magic_card.scryfall_oracle_id.present?

      items.any_printing.for_oracle(@magic_card.scryfall_oracle_id).first
    end

    # switching a printing-specific row to "any" collides with an any-printing row for the same card
    def error_message(item)
      if item.errors.of_kind?(:scryfall_oracle_id, :taken)
        "You already want any printing of #{item.magic_card.name}."
      else
        item.errors.full_messages.to_sentence
      end
    end

    def cleaned_attributes(item)
      {
        quantity: [(@attributes[:quantity].presence || item.quantity || 1).to_i, 1].max,
        foil_preference: @attributes[:foil_preference].presence || item.foil_preference,
        any_printing: any_printing?(item),
        notes: @attributes.key?(:notes) ? @attributes[:notes].to_s.strip.presence : item.notes
      }
    end

    # an omitted flag keeps what the row has; a new row defaults to any printing like the column does
    def any_printing?(item)
      return item.nil? || item.any_printing unless @attributes.key?(:any_printing)

      ActiveModel::Type::Boolean.new.cast(@attributes[:any_printing]) || false
    end
  end
end
