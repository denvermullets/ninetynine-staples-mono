module CardAnalysis
  class BatchProfiler < Service
    # every ancestor of each tag a card carries, including the tag itself (the depth-0 closure row)
    TAG_ANCESTRY_JOIN = <<~SQL.squish.freeze
      JOIN oracle_tag_ancestors ON oracle_tag_ancestors.descendant_id = card_oracle_tags.oracle_tag_id
      JOIN oracle_tags ON oracle_tags.id = oracle_tag_ancestors.ancestor_id
    SQL

    def initialize(batch_size: 1000, oracle_ids: nil)
      @batch_size = batch_size
      @oracle_ids = oracle_ids
    end

    def call
      processed = 0
      roles_created = 0

      distinct_oracle_ids.each_slice(@batch_size) do |oid_batch|
        cards = load_cards(oid_batch)
        roles = profile_batch(cards, tag_slugs_by_oracle(oid_batch))
        processed += cards.size

        roles_created += upsert_roles(roles, oid_batch)
        log_progress(processed, roles_created)
      end

      log_complete(processed, roles_created)
      { success: true, processed: processed, roles_created: roles_created }
    end

    private

    def load_cards(oid_batch)
      MagicCard
        .where(scryfall_oracle_id: oid_batch, is_token: false, card_side: [nil, 'a'])
        .includes(:keywords, :sub_types)
        .group_by(&:scryfall_oracle_id)
    end

    # Scryfall's tags only, expanded through the hierarchy: a card tagged removal-destroy also carries every
    # ancestor of that tag. User tags (STA-284) are deliberately left out - they are unmoderated, and
    # TaggerDetector writes at confidence 1.0.
    # -> { oracle_id => [slug, ...] }
    def tag_slugs_by_oracle(oid_batch)
      CardOracleTag.from_scryfall
                   .where(scryfall_oracle_id: oid_batch)
                   .where.not(oracle_tag_id: OracleTag.where(disabled: true).select(:id))
                   .joins(TAG_ANCESTRY_JOIN)
                   .where(oracle_tags: { disabled: false })
                   .distinct
                   .pluck(:scryfall_oracle_id, 'oracle_tags.slug')
                   .group_by(&:first)
                   .transform_values { |pairs| pairs.map(&:last) }
    end

    def profile_batch(cards, tag_slugs)
      cards.each_value.flat_map do |dupes|
        card = dupes.first
        profile_card(card, tag_slugs.fetch(card.scryfall_oracle_id, []))
      end
    end

    def profile_card(card, tag_slugs)
      RoleProfiler.call(
        scryfall_oracle_id: card.scryfall_oracle_id,
        oracle_text: card.text,
        card_type: card.card_type,
        keywords: card.keywords.map(&:keyword),
        subtypes: card.sub_types.map(&:name),
        mana_value: card.mana_value,
        power: card.power,
        layout: card.layout,
        tag_slugs: tag_slugs
      ).map do |result|
        {
          scryfall_oracle_id: card.scryfall_oracle_id,
          role: result[:role],
          effect: result[:effect],
          confidence: result[:confidence],
          source: result[:source]
        }
      end
    end

    # A re-profile replaces a card's roles rather than adding to them: whatever the rules and tags no longer
    # produce is deleted. Without that, a tag Scryfall retracts would leave its 1.0 tagger row in place
    # forever, and so would any pattern row from a rule that has since been tightened.
    def upsert_roles(roles, oid_batch)
      kept_ids = if roles.empty?
                   []
                 else
                   CardRole.upsert_all(
                     roles,
                     unique_by: 'idx_card_roles_unique',
                     update_only: %i[confidence source],
                     returning: %w[id]
                   ).rows.flatten
                 end

      CardRole.where(scryfall_oracle_id: oid_batch).where.not(id: kept_ids).delete_all
      roles.size
    end

    def log_progress(processed, roles_created)
      return unless (processed % 1000).zero?

      Rails.logger.info(
        "[CardAnalysis::BatchProfiler] Processed #{processed} cards, " \
        "#{roles_created} roles upserted"
      )
    end

    def log_complete(processed, roles_created)
      Rails.logger.info(
        "[CardAnalysis::BatchProfiler] Complete: #{processed} cards processed, " \
        "#{roles_created} roles upserted"
      )
    end

    def distinct_oracle_ids
      scope = MagicCard
              .where(is_token: false)
              .where(card_side: [nil, 'a'])
              .where.not(scryfall_oracle_id: nil)

      scope = scope.where(scryfall_oracle_id: @oracle_ids) if @oracle_ids.present?
      scope.distinct.pluck(:scryfall_oracle_id)
    end
  end
end
