class FeaturesController < ApplicationController
  def show
    min_id = MagicCard.minimum(:id)
    max_id = MagicCard.maximum(:id)
    ids = Array.new(20) { rand(min_id..max_id) }

    @hero_cards = MagicCard
                  .where.not(image_medium: [nil, ''])
                  .where(id: ids, is_token: false)
                  .limit(9)
  end
end
