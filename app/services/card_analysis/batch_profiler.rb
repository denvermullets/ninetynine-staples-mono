module CardAnalysis
  class BatchProfiler < Service
    def initialize(batch_size: 1000, oracle_ids: nil)
      @batch_size = batch_size
      @oracle_ids = oracle_ids
    end

    def call
      processed = 0
      roles_created = 0

      distinct_oracle_ids.each_slice(@batch_size) do |oid_batch|
        cards = load_cards(oid_batch)
        roles = profile_batch(cards)
        processed += cards.size

        roles_created += upsert_roles(roles)
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

    def profile_batch(cards)
      cards.each_value.flat_map do |dupes|
        card = dupes.first
        profile_card(card)
      end
    end

    def profile_card(card)
      RoleProfiler.call(
        scryfall_oracle_id: card.scryfall_oracle_id,
        oracle_text: card.text,
        card_type: card.card_type,
        keywords: card.keywords.map(&:keyword),
        subtypes: card.sub_types.map(&:name),
        mana_value: card.mana_value,
        power: card.power,
        layout: card.layout
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

    def upsert_roles(roles)
      return 0 if roles.empty?

      CardRole.upsert_all(
        roles,
        unique_by: 'idx_card_roles_unique',
        update_only: %i[confidence source]
      )
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
