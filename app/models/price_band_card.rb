# Where one card a price band watches sits relative to the band: one row per band, printing and
# finish. `crossed` is past the band's threshold; `armed` is not, and is waiting to reach it.
#
# A row is listed - on the band's worklist - when it carries a crossing: the day (`crossed_on`), the
# price, and which way it `moved`. Ticking it off sets `handled_at`, and it moves to the done tab. A
# card that has not crossed anything since the band learned it is not listed at all. Written by
# PriceAlerts::SyncBand, ticked off by PriceBandWorklistsController.
class PriceBandCard < ApplicationRecord
  STATES = %w[armed crossed].freeze
  FINISHES = %w[normal foil].freeze

  belongs_to :band, class_name: 'PriceAlert', foreign_key: :price_alert_id, inverse_of: :band_cards
  belongs_to :magic_card

  validates :state, inclusion: { in: STATES }
  validates :finish, inclusion: { in: FINISHES }
  validates :moved, inclusion: { in: PriceAlertBands::MOVES }, allow_nil: true

  scope :listed, -> { where.not(crossed_on: nil) }
  scope :to_do, -> { listed.where(handled_at: nil) }
  scope :done, -> { listed.where.not(handled_at: nil) }

  def armed?
    state == 'armed'
  end

  def crossed?
    state == 'crossed'
  end

  def to_do?
    crossed_on.present? && handled_at.nil?
  end
end
