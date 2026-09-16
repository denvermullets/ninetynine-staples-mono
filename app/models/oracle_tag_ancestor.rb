# One row per (ancestor, descendant) pair in the tag hierarchy, including a depth-0 row per tag for itself.
# Rebuilt wholesale by Scryfall::OracleTagsImporter; never edited in place.
class OracleTagAncestor < ApplicationRecord
  belongs_to :ancestor, class_name: 'OracleTag'
  belongs_to :descendant, class_name: 'OracleTag'
end
