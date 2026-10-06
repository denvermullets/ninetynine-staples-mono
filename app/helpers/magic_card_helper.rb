module MagicCardHelper
  # A flat gradient rather than a bg- color so the tint layers over whatever background the row
  # already has - bg-foreground at rest, hover:bg-menu on hover - instead of replacing it.
  RESERVED_TINT = 'bg-linear-to-r from-ink-gold-accent/10 to-ink-gold-accent/10'.freeze

  def reserved_tint_class(card)
    RESERVED_TINT if card.is_reserved
  end
end
