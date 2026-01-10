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
  DEFAULT_PREFERENCES = {
    "collection_order" => [],
    "visible_columns" => {
      "card_number" => true,
      "name" => true,
      "type" => true,
      "mana" => true,
      "regular_price" => true,
      "foil_price" => true
    }
  }.freeze

  COLUMN_KEYS = %w[card_number name type mana regular_price foil_price].freeze

  def effective_preferences
    DEFAULT_PREFERENCES.deep_merge(preferences || {})
  end

  def collection_order
    effective_preferences["collection_order"] || []
  end

  def collection_order=(order)
    self.preferences = (preferences || {}).merge("collection_order" => order)
  end

  def visible_columns
    effective_preferences["visible_columns"]
  end

  def visible_columns=(columns)
    self.preferences = (preferences || {}).merge("visible_columns" => columns)
  end

  def column_visible?(column_key)
    visible_columns[column_key] != false
  end

  def ordered_collections
    order = collection_order
    if order.present?
      collections.sort_by { |c| [ order.index(c.id) || Float::INFINITY, c.id ] }
    else
      collections.order(:id).to_a
    end
  end

  def move_collection(collection_id, direction)
    collection_id = collection_id.to_i
    current_order = collection_order.presence || collections.order(:id).pluck(:id)

    # Ensure the collection is in the order array
    unless current_order.include?(collection_id)
      return false unless collections.exists?(collection_id)
      current_order << collection_id
    end

    index = current_order.index(collection_id)
    return false if index.nil?

    new_index = direction == "up" ? index - 1 : index + 1
    return false if new_index < 0 || new_index >= current_order.length

    # Swap positions
    current_order[index], current_order[new_index] = current_order[new_index], current_order[index]
    self.collection_order = current_order
    save
  end
end
