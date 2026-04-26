# Bulk applies a batch of card moves where each row carries its own from/to collection.
# A row's amounts are deltas to move from FROM -> TO. When FROM is the "new" sentinel,
# amounts are added to TO via CreateOrUpdate (which expects new totals, so we pre-add to
# the current TO qty). Rows missing from, to, or any qty > 0 are silently skipped.
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
      new_totals = AMOUNT_KEYS.to_h do |k|
        [k, (existing&.public_send(k) || 0) + amounts[k]]
      end

      result = CreateOrUpdate.call(params: new_totals.merge(
        collection_id: to_id, magic_card_id: row[:magic_card_id], card_uuid: row[:card_uuid]
      ))
      base_row(row, action: result[:action])
    end

    def apply_transfer(row, amounts, from_id, to_id)
      result = Transfer.call(params: amounts.merge(
        magic_card_id: row[:magic_card_id], from_collection_id: from_id, to_collection_id: to_id
      ))
      base_row(row, action: result[:success] ? :transferred : :error, error: result[:success] ? nil : result[:error])
    end

    def base_row(row, action:, error: nil)
      {
        magic_card_id: row[:magic_card_id], card_uuid: row[:card_uuid],
        from_collection_id: row[:from_collection_id], to_collection_id: row[:to_collection_id],
        action: action, error: error
      }
    end

    def error_row(row, message)
      base_row(row, action: :error, error: message)
    end
  end
end
