class DecksController < ApplicationController
  SORT_OPTIONS = {
    'updated_desc' => { label: 'Recently Updated', order: { updated_at: :desc } },
    'building' => { label: 'Building', order: nil },
    'created_desc' => { label: 'Newest First', order: { created_at: :desc } },
    'created_asc' => { label: 'Oldest First', order: { created_at: :asc } },
    'name_asc' => { label: 'Name (A-Z)', order: { name: :asc } },
    'name_desc' => { label: 'Name (Z-A)', order: { name: :desc } },
    'value_desc' => { label: 'Value (High-Low)', order: { total_value: :desc } },
    'value_asc' => { label: 'Value (Low-High)', order: { total_value: :asc } }
  }.freeze

  BUILDING_SELECT_SQL = <<~SQL.squish
    collections.*,
    EXISTS(
      SELECT 1 FROM collection_magic_cards
      WHERE collection_magic_cards.collection_id = collections.id
      AND collection_magic_cards.staged = true
    ) AS is_building
  SQL

  def index
    @user = User.find_by!(username: params[:username])
    @sort = params[:sort].presence_in(SORT_OPTIONS.keys) || 'updated_desc'
    @sort_options = SORT_OPTIONS
    @is_owner = current_user&.id == @user.id
    base_decks = @user.collections.decks.includes(:tags)
    base_decks = base_decks.visible_to_public unless @is_owner
    @decks = sorted_decks(base_decks)
  end

  private

  def sorted_decks(decks)
    return decks.order(SORT_OPTIONS[@sort][:order]) unless @sort == 'building'

    decks.left_joins(:collection_magic_cards)
         .select(BUILDING_SELECT_SQL)
         .group('collections.id')
         .order(Arel.sql('is_building DESC, collections.updated_at DESC'))
  end
end
