module Admin
  class OrphanedCardsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin

    def index
      @pagy, @orphaned_groups = find_orphaned_cards
    end

    def destroy
      @card = MagicCard.find(params[:id])
      collection_count = @card.collection_magic_cards.count

      if collection_count.positive?
        msg = "Cannot delete '#{@card.name}' — it exists in #{collection_count} collection(s). Reassign those first."
        redirect_to admin_orphaned_cards_path, alert: msg
      else
        @card.destroy
        redirect_to admin_orphaned_cards_path,
                    notice: "'#{@card.name}' (ID: #{params[:id]}) deleted successfully."
      end
    end

    private

    def ensure_admin
      redirect_to(root_path, alert: 'Access denied') unless current_user&.role.to_i == 9001
    end

    def find_orphaned_cards
      all_keys = duplicate_group_keys
      pagy = Pagy::Offset.new(count: all_keys.size, page: params[:page] || 1, limit: 25, request: request)
      page_keys = all_keys[pagy.offset, pagy.limit] || []

      return [pagy, []] if page_keys.empty?

      [pagy, build_groups(page_keys)]
    end

    def duplicate_group_keys
      not_art_series = MagicCard.where(layout: 'art_series').select(:id)

      MagicCard
        .where.not(id: not_art_series)
        .select(:name, :boxset_id, :card_number)
        .group(:name, :boxset_id, :card_number)
        .having('COUNT(*) > 1')
        .order(:name, :boxset_id, :card_number)
        .map { |g| { name: g.name, boxset_id: g.boxset_id, card_number: g.card_number } }
    end

    def build_groups(page_keys)
      relation = page_keys.reduce(MagicCard.none) do |combined, key|
        combined.or(MagicCard.where(name: key[:name], boxset_id: key[:boxset_id], card_number: key[:card_number]))
      end

      relation
        .includes(:boxset, :collection_magic_cards)
        .order(:name, :boxset_id, :card_number, :updated_at)
        .group_by { |c| [c.name, c.boxset_id, c.card_number] }
        .map { |key, cards| build_group_hash(key, cards) }
    end

    def build_group_hash(key, cards)
      sorted = cards.sort_by(&:updated_at)
      {
        name: key[0],
        boxset: cards.first.boxset,
        card_number: key[2],
        orphan: sorted.first,
        good_card: sorted.last,
        all_cards: sorted
      }
    end
  end
end
