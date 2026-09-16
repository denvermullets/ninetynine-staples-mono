# Writes Scryfall's Oracle Tags bulk file into oracle_tags, card_oracle_tags and oracle_tag_ancestors.
#
# Everything runs in one transaction: a half-imported file would leave the closure table pointing at tags
# that no longer carry their cards. Only source 'scryfall' rows are written or removed, so user tags
# (STA-284) survive every run.
#
# changed_oracle_ids is what the caller should re-profile: cards that gained or lost a direct tagging, plus
# cards tagged with anything whose place in the hierarchy moved. On a first run that is every tagged card.
module Scryfall
  class OracleTagsImporter < Service
    RECORD_BATCH = 500
    SLICE = 1000

    class EmptyFileError < StandardError; end

    # records: anything yielding parsed tag hashes - Scryfall::BulkData.each_record in production
    def initialize(records:)
      @records = records
      @parents = {}
      @seen_scryfall_ids = Set.new
      @seen_pairs = Set.new
      @changed = Set.new
      @tag_count = 0
      @tagging_count = 0
    end

    def call
      ActiveRecord::Base.transaction do
        @records.each_slice(RECORD_BATCH) { |batch| import_batch(batch) }
        # an empty or unparseable file must not read as "Scryfall deleted every tag"
        raise EmptyFileError, 'oracle tags file contained no tags' if @tag_count.zero?

        remove_stale_taggings
        rebuild_closure
      end

      log "Imported #{@tag_count} tags, #{@tagging_count} taggings, #{@changed.size} cards changed"
      { tag_count: @tag_count, tagging_count: @tagging_count, changed_oracle_ids: @changed.to_a }
    end

    private

    def log(message) = Rails.logger.info("[Scryfall::OracleTagsImporter] #{message}")

    def import_batch(batch)
      tags = batch.select { |record| record['object'] == 'tag' && record['type'] == 'oracle' }
      return if tags.empty?

      ids = upsert_tags(tags)
      tags.each { |tag| @parents[tag['id']] = Array(tag['parent_ids']) }
      rows = tags.flat_map { |tag| tagging_rows(ids.fetch(tag['id']), tag['taggings']) }
      rows.each_slice(SLICE) { |slice| upsert_taggings(slice) }
    end

    # -> { scryfall_id => oracle_tags.id }
    def upsert_tags(tags)
      rows = tags.map { |tag| tag_row(tag) }
      release_slugs(rows)

      result = OracleTag.upsert_all(rows, unique_by: :scryfall_id,
                                          update_only: %i[slug label description aliases],
                                          returning: %w[id scryfall_id])
      @tag_count += rows.size
      @seen_scryfall_ids.merge(rows.pluck(:scryfall_id))
      result.rows.to_h { |id, scryfall_id| [scryfall_id, id] }
    end

    def tag_row(tag)
      {
        scryfall_id: tag['id'], slug: tag['slug'], label: tag['label'].presence || tag['slug'],
        description: tag['description'], aliases: Array(tag['aliases']), source: 'scryfall'
      }
    end

    # Slugs are unique but Scryfall may hand one to a different tag (a rename or a swap). Whatever holds it
    # now steps aside under a name nobody else can have; a Scryfall tag gets its real slug back when its own
    # record arrives, and a user tag keeps the suffixed name.
    def release_slugs(rows)
      wanted = rows.to_h { |row| [row[:slug], row[:scryfall_id]] }

      OracleTag.where(slug: wanted.keys).find_each do |tag|
        next if tag.scryfall_id.present? && tag.scryfall_id == wanted[tag.slug]

        freed = "#{tag.slug}-#{tag.source}-#{tag.id}"
        log "slug #{tag.slug} now belongs to Scryfall tag #{wanted[tag.slug]}; tag #{tag.id} renamed #{freed}"
        tag.update_columns(slug: freed)
      end
    end

    def tagging_rows(tag_id, taggings)
      Array(taggings).filter_map do |tagging|
        oracle_id = tagging['oracle_id']
        next if oracle_id.blank? || !@seen_pairs.add?("#{tag_id}:#{oracle_id}")

        { oracle_tag_id: tag_id, scryfall_oracle_id: oracle_id, weight: tagging['weight'],
          annotation: tagging['annotation'], source: 'scryfall' }
      end
    end

    # xmax is 0 only on a row this statement inserted, which is how a fresh tagging is told apart from one
    # that was already there.
    def upsert_taggings(rows)
      result = CardOracleTag.upsert_all(
        rows,
        unique_by: 'idx_card_oracle_tags_unique',
        update_only: %i[weight annotation],
        returning: Arel.sql('CASE WHEN xmax = 0 THEN scryfall_oracle_id END AS inserted_oracle_id')
      )
      @changed.merge(result.rows.flatten.compact)
      @tagging_count += rows.size
    end

    def remove_stale_taggings
      stale = CardOracleTag.from_scryfall.pluck(:id, :oracle_tag_id, :scryfall_oracle_id)
                           .reject { |_, tag_id, oracle_id| @seen_pairs.include?("#{tag_id}:#{oracle_id}") }
      return if stale.empty?

      @changed.merge(stale.map(&:last))
      stale.map(&:first).each_slice(SLICE) { |ids| CardOracleTag.where(id: ids).delete_all }
    end

    def rebuild_closure
      before = ancestry_sets
      OracleTagAncestor.delete_all
      remove_stale_tags

      rows = OracleTagClosure.call(parents: parent_map)
      rows.each_slice(SLICE) { |slice| OracleTagAncestor.insert_all(slice) }
      mark_moved_tags(before, rows)
    end

    # Tags Scryfall dropped. One a user has applied to a card is kept as a user tag instead of taking the
    # user's tagging down with it.
    def remove_stale_tags
      stale_ids = OracleTag.where(source: 'scryfall').where.not(scryfall_id: @seen_scryfall_ids.to_a).pluck(:id)
      return if stale_ids.empty?

      kept = CardOracleTag.from_users.where(oracle_tag_id: stale_ids).distinct.pluck(:oracle_tag_id)
      OracleTag.where(id: kept).update_all(source: 'user', scryfall_id: nil)
      OracleTag.where(id: stale_ids - kept).delete_all
    end

    # { tag_id => [parent_tag_id, ...] } for every tag, translated from Scryfall ids
    def parent_map
      id_for = OracleTag.where.not(scryfall_id: nil).pluck(:scryfall_id, :id).to_h

      OracleTag.pluck(:id, :scryfall_id).to_h do |id, scryfall_id|
        [id, Array(@parents[scryfall_id]).filter_map { |parent| id_for[parent] }]
      end
    end

    def ancestry_sets
      OracleTagAncestor.pluck(:descendant_id, :ancestor_id)
                       .group_by(&:first).transform_values { |pairs| pairs.to_set(&:last) }
    end

    def mark_moved_tags(before, rows)
      after = rows.group_by { |row| row[:descendant_id] }
                  .transform_values { |group| group.to_set { |row| row[:ancestor_id] } }
      moved = after.keys.reject { |tag_id| before[tag_id] == after[tag_id] }
      return if moved.empty?

      @changed.merge(CardOracleTag.from_scryfall.where(oracle_tag_id: moved).distinct.pluck(:scryfall_oracle_id))
    end
  end
end
