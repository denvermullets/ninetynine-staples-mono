class User < ApplicationRecord
  has_secure_password
  has_many :collections

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :username, presence: true
  validates :password, length: { minimum: 10 }, allow_nil: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :password_reset, expires_in: 1.hour do
    password_digest&.last(10)
  end

  # Preferences
  DEFAULT_COLUMN_VISIBILITY = {
    'card_number' => true,
    'name' => true,
    'type' => true,
    'mana' => true,
    'regular_price' => true,
    'foil_price' => true,
    'salt' => false
  }.freeze

  DEFAULT_PREFERENCES = {
    'collection_order' => [],
    'visible_columns_collections' => DEFAULT_COLUMN_VISIBILITY,
    'visible_columns_boxsets' => DEFAULT_COLUMN_VISIBILITY
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

  def view_key(view)
    case view&.to_s
    when 'boxsets'
      'visible_columns_boxsets'
    else
      'visible_columns_collections'
    end
  end

  def ordered_collections
    order = collection_order
    if order.present?
      collections.sort_by { |c| [order.index(c.id) || Float::INFINITY, c.id] }
    else
      collections.order(:id).to_a
    end
  end

  def move_collection(collection_id, direction)
    collection_id = collection_id.to_i
    current_order = ensure_collection_in_order(collection_id)
    return false unless current_order

    swap_collection_position(current_order, collection_id, direction)
  end

  private

  def ensure_collection_in_order(collection_id)
    order = collection_order.presence || collections.order(:id).pluck(:id)
    return order if order.include?(collection_id)
    return nil unless collections.exists?(collection_id)

    order << collection_id
    order
  end

  def swap_collection_position(current_order, collection_id, direction)
    index = current_order.index(collection_id)
    new_index = direction == 'up' ? index - 1 : index + 1
    return false if new_index.negative? || new_index >= current_order.length

    current_order[index], current_order[new_index] = current_order[new_index], current_order[index]
    self.collection_order = current_order
    save
  end
end
