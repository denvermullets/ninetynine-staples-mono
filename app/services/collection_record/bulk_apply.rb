# Bulk applies a batch of card edits where each row carries its own from/to collection.
# A row's amounts mean one of two things depending on FROM:
#   - FROM is the "new" sentinel: amounts are the resulting TOTALS in TO, written straight
#     through by CreateOrUpdate. A row already matching those totals is a :noop.
#   - FROM is a real collection: amounts are deltas to move from FROM -> TO via Transfer.
# Rows missing from, to, or any qty > 0 are silently skipped, so a row left untouched
# never writes anything (and bulk edit cannot zero a card out - use the adjust modal).
# All-or-nothing: any row error rolls back the batch.
module CollectionRecord
  class BulkApply < Service
    BRAND_NEW = 'new'.freeze
    AMOUNT_KEYS = %i[quantity foil_quantity proxy_quantity proxy_foil_quantity].freeze

    def initialize(rows:, user:)
      @rows = rows || []
      @user = user
    end

    def call
      results = []
      ActiveRecord::Base.transaction do
        @rows.each do |row|
          row = row.with_indifferent_access
          result = apply_row(row)
          results << result if result
        end
        raise ActiveRecord::Rollback if results.any? { |r| r[:error] }
      end

      processed = results.reject { |r| r[:action] == :noop }
      { success: results.none? { |r| r[:error] }, results: results, processed_count: processed.size }
    end

    private

    def apply_row(row)
      amounts = AMOUNT_KEYS.index_with { |k| [row[k].to_i, 0].max }
      return nil if amounts.values.all?(&:zero?)

      from_id = row[:from_collection_id].presence
      to_id = row[:to_collection_id].presence
      return nil if from_id.blank? || to_id.blank?

      validation = validate_row(from_id, to_id)
      return error_row(row, validation) if validation

      brand_new = from_id.to_s == BRAND_NEW
      brand_new ? apply_brand_new(row, amounts, to_id) : apply_transfer(row, amounts, from_id, to_id)
    end

    def validate_row(from_id, to_id)
      return "'Brand new' cannot be the destination" if to_id.to_s == BRAND_NEW
      return 'FROM and TO must differ' if from_id.to_s != BRAND_NEW && from_id.to_i == to_id.to_i

      ids = [from_id.to_s == BRAND_NEW ? nil : from_id.to_i, to_id.to_i].compact
      return 'Collection does not belong to current user' unless @user.collections.where(id: ids).count == ids.size

      nil
    end

    def apply_brand_new(row, amounts, to_id)
      existing = CollectionMagicCard.find_by(
        collection_id: to_id, magic_card_id: row[:magic_card_id], card_uuid: row[:card_uuid]
      )
      return base_row(row, action: :noop) if already_at_totals?(existing, amounts)

      result = CreateOrUpdate.call(params: amounts.merge(
        collection_id: to_id, magic_card_id: row[:magic_card_id], card_uuid: row[:card_uuid]
      ))
      base_row(row, action: result[:action])
    end

    def already_at_totals?(existing, amounts)
      return false if existing.nil?

      AMOUNT_KEYS.all? { |key| existing.public_send(key).to_i == amounts[key] }
    end

    def apply_transfer(row, amounts, from_id, to_id)
      result = Transfer.call(params: amounts.merge(
        magic_card_id: row[:magic_card_id], card_uuid: row[:card_uuid],
        from_collection_id: from_id, to_collection_id: to_id
      ))
      base_row(row, action: result[:success] ? :transferred : :error, error: result[:success] ? nil : result[:error])
    end

    def base_row(row, action:, error: nil)
      {
        magic_card_id: row[:magic_card_id], card_uuid: row[:card_uuid], name: card_name(row[:magic_card_id]),
        from_collection_id: row[:from_collection_id], to_collection_id: row[:to_collection_id],
        action: action, error: error
      }
    end

    # only rows we actually touched get looked up, and each card at most once
    def card_name(magic_card_id)
      @card_names ||= {}
      return @card_names[magic_card_id] if @card_names.key?(magic_card_id)

      @card_names[magic_card_id] = MagicCard.find_by(id: magic_card_id)&.name
    end

    def error_row(row, message)
      base_row(row, action: :error, error: message)
    end
  end
end
