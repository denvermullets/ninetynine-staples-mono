# What to call a printing that is not the plain one: showcase, borderless, extended art, etched.
#
# The set detail page needs these to label the variant sub-rows - "312 borderless" is a card you can
# go and find, "312" on its own is a number. They live in join tables (magic_card_frame_effects and,
# for etched, magic_card_finishes), and a printing can carry several of each.
#
# Deliberately a second query over the visible page rather than part of SetCards' scan. Joining both
# tables into that query fans a printing out to one row per effect times one row per finish, which
# needs array_agg(DISTINCT ...) and a GROUP BY carrying every plucked column just to get back to one
# row per printing. Fifty ids and two indexed lookups is cheaper and reads like what it is.
#
# Only the finishes that describe how a card LOOKS come through. nonfoil and foil are how you buy a
# printing, not which printing it is, and labelling half a set "foil" says nothing.
module CollectionStats
  class PrintingLabels < Service
    LOOK_FINISHES = %w[etched].freeze

    def initialize(magic_card_ids:)
      @magic_card_ids = Array(magic_card_ids).compact.uniq
    end

    def call
      return {} if @magic_card_ids.empty?

      merge(frame_effects, finishes)
    end

    private

    def frame_effects
      FrameEffect.joins(:magic_card_frame_effects)
                 .where(magic_card_frame_effects: { magic_card_id: @magic_card_ids })
                 .pluck('magic_card_frame_effects.magic_card_id', :name)
    end

    def finishes
      Finish.joins(:magic_card_finishes)
            .where(magic_card_finishes: { magic_card_id: @magic_card_ids }, name: LOOK_FINISHES)
            .pluck('magic_card_finishes.magic_card_id', :name)
    end

    # Frame effects first, finishes after: "showcase etched" is the order somebody would say it in,
    # and the frame is the part that tells you which printing you are looking at.
    def merge(*sources)
      sources.flatten(1).each_with_object({}) do |(id, name), labels|
        next if name.blank?

        (labels[id] ||= []) << name.humanize.downcase
      end
    end
  end
end
