module CardAnalysis
  # Scores candidates by how well their card_roles line up with a set of weighted (role, effect) targets.
  #
  # The formula is a confidence product: each matched pair contributes candidate_confidence * target_weight,
  # summed across pairs. ReplacementFinder passes the source card's own confidence as the weight, which
  # makes this exactly the arithmetic it did inline. CommanderSynergy passes a theme weight instead, so a
  # commander that screams sacrifice pulls harder than one incidentally tagged with a role.
  #
  # The sum is unbounded above - a card matching five pairs scores roughly five times one matching one - so
  # anything blending this against another axis has to normalize first.
  class ConfidenceScorer < Service
    # Ordered by id so the result matches what find_each produced when this lived inside ReplacementFinder.
    def self.rows_for(oracle_ids)
      CardRole.where(scryfall_oracle_id: oracle_ids)
              .order(:id)
              .pluck(:scryfall_oracle_id, :role, :effect, :confidence)
    end

    def initialize(rows:, targets:)
      @rows = rows
      @targets = targets
    end

    # -> { oracle_id => { score: Float, matched_roles: [{ role:, effect: }] } }, only for candidates that
    # matched at least one target.
    def call
      scores = Hash.new { |hash, key| hash[key] = { score: 0.0, matched_roles: [] } }
      @rows.each { |oracle_id, role, effect, confidence| accumulate(scores, oracle_id, role, effect, confidence) }
      scores
    end

    private

    def accumulate(scores, oracle_id, role, effect, confidence)
      weight = @targets[[role, effect]]
      return unless weight

      entry = scores[oracle_id]
      entry[:score] += confidence * weight
      entry[:matched_roles] << { role: role, effect: effect }
    end
  end
end
