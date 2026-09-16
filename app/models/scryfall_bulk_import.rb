# When each Scryfall bulk file was last imported, so a daily job can skip a file that has not changed.
class ScryfallBulkImport < ApplicationRecord
  validates :bulk_type, presence: true, uniqueness: true
end
