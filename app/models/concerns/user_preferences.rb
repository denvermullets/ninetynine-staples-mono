module UserPreferences
  extend ActiveSupport::Concern

  DEFAULT_COLUMN_VISIBILITY = {
    'card_number' => true, 'name' => true, 'type' => true, 'mana' => true,
    'regular_price' => true, 'foil_price' => true, 'salt' => false
  }.freeze

  DEFAULT_PREFERENCES = {
    'collection_order' => [],
    'visible_columns_collections' => DEFAULT_COLUMN_VISIBILITY,
    'visible_columns_boxsets' => DEFAULT_COLUMN_VISIBILITY,
    'theme' => 'dark'
  }.freeze

  COLUMN_KEYS = %w[card_number name type mana regular_price foil_price salt].freeze

  def effective_preferences
    DEFAULT_PREFERENCES.deep_merge(preferences || {})
  end

  def collection_order
    effective_preferences['collection_order'] || []
  end

  def collection_order=(order)
    self.preferences = (preferences || {}).merge('collection_order' => order)
  end

  def visible_columns(view = nil)
    key = view_key(view)
    effective_preferences[key] || DEFAULT_COLUMN_VISIBILITY
  end

  def visible_columns=(columns, view: nil)
    key = view_key(view)
    self.preferences = (preferences || {}).merge(key => columns)
  end

  def set_visible_columns(columns, view:)
    key = view_key(view)
    self.preferences = (preferences || {}).merge(key => columns)
  end

  def column_visible?(column_key, view = nil)
    visible_columns(view)[column_key] != false
  end

  def theme
    effective_preferences['theme'] || 'dark'
  end

  def theme=(value)
    self.preferences = (preferences || {}).merge('theme' => value)
  end

  private

  def view_key(view)
    case view&.to_s
    when 'boxsets'
      'visible_columns_boxsets'
    else
      'visible_columns_collections'
    end
  end
end
