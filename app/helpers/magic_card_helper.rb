module MagicCardHelper
  # A flat gradient rather than a bg- color so the tint layers over whatever background the row
  # already has - bg-foreground at rest, hover:bg-menu on hover - instead of replacing it.
  RESERVED_TINT = 'bg-linear-to-r from-ink-gold-accent/10 to-ink-gold-accent/10'.freeze

  def reserved_tint_class(card)
    RESERVED_TINT if card.is_reserved
  end

  # data attributes for one "Add to collection" option: the copies of this printing that collection
  # already holds, so the add modal can show them. Only the record the add will land on counts - the
  # one keyed by this printing's card_uuid.
  def add_to_collection_option_data(collection, magic_card, card_locations)
    held = card_locations.find do |location|
      location.collection_id == collection.id && location.card_uuid == magic_card.card_uuid
    end

    { regular_qty: held&.quantity.to_i, foil_qty: held&.foil_quantity.to_i,
      proxy_qty: held&.proxy_quantity.to_i, proxy_foil_qty: held&.proxy_foil_quantity.to_i }
  end
end
