# A functional ("oracle") tag, mostly from Scryfall's community Tagger project via the daily bulk file.
#
# Keyed on scryfall_id, not slug: Scryfall says slugs may be renamed and the uuid is the stable reference.
# User-created tags (STA-284) have no scryfall_id.
class OracleTag < ApplicationRecord
  SOURCES = %w[scryfall user].freeze

  has_many :card_oracle_tags, dependent: :delete_all
  has_many :descendant_links, class_name: 'OracleTagAncestor', foreign_key: :ancestor_id, dependent: :delete_all
  has_many :ancestor_links, class_name: 'OracleTagAncestor', foreign_key: :descendant_id, dependent: :delete_all
  belongs_to :created_by, class_name: 'User', optional: true

  validates :slug, presence: true, uniqueness: true
  validates :label, presence: true
  validates :source, inclusion: { in: SOURCES }

  # otag: joins the closure table, so a tag with no depth-0 row of its own is unsearchable. The ingest
  # rebuilds the closure wholesale (and upsert_all skips callbacks); this covers a tag created in between.
  after_create :add_self_ancestry

  scope :enabled, -> { where(disabled: false) }
  scope :alphabetical, -> { order(:label) }

  TAGGER_URL = 'https://tagger.scryfall.com/tags/card/'.freeze

  # Attribution: every Scryfall tag links back to its page on Tagger. User tags have nowhere to link.
  def tagger_url
    return nil if scryfall_id.blank?

    "#{TAGGER_URL}#{ERB::Util.url_encode(slug)}"
  end

  # What someone typed after otag: - a slug, a label, or one of the community aliases. Case-insensitive
  # and hyphens are kept: tag slugs are hyphenated, unlike card_roles effects.
  def self.resolve(value)
    term = value.to_s.strip.downcase
    return nil if term.empty?

    find_by(slug: [term, term.tr(' ', '-')].uniq) ||
      find_by('LOWER(label) = ?', term) ||
      find_by('? = ANY(aliases)', term)
  end

  private

  def add_self_ancestry
    OracleTagAncestor.insert_all([{ ancestor_id: id, descendant_id: id, depth: 0 }],
                                 unique_by: %i[descendant_id ancestor_id])
  end
end
