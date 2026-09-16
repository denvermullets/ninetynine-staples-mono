# A tag applied to a card, per oracle id rather than per printing. Scryfall rows are owned by the ingest
# and replaced every run; user rows (STA-284) are never touched by it.
class CardOracleTag < ApplicationRecord
  SOURCES = OracleTag::SOURCES

  belongs_to :oracle_tag
  belongs_to :user, optional: true

  validates :scryfall_oracle_id, presence: true
  validates :source, inclusion: { in: SOURCES }

  scope :from_scryfall, -> { where(source: 'scryfall') }
  scope :from_users, -> { where(source: 'user') }

  # Scryfall's curated tags lead; anything users added follows.
  scope :ordered, lambda {
    joins(:oracle_tag)
      .order(Arel.sql("CASE card_oracle_tags.source WHEN 'scryfall' THEN 0 ELSE 1 END"))
      .order('oracle_tags.label')
  }
end
