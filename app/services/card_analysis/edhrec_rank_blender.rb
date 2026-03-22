module CardAnalysis
  class EdhrecRankBlender
    def initialize(scores)
      @scores = scores
    end

    def blend
      ranks = load_ranks
      return if ranks.empty?

      max_rank = ranks.values.max.to_f
      return if max_rank.zero?

      @scores.each do |oid, data|
        rank = ranks[oid]
        next unless rank

        apply_boost(data, rank, max_rank)
      end
    end

    private

    def load_ranks
      MagicCard
        .where(scryfall_oracle_id: @scores.keys, card_side: [nil, 'a'])
        .where.not(edhrec_rank: nil)
        .group(:scryfall_oracle_id)
        .minimum(:edhrec_rank)
    end

    def apply_boost(data, rank, max_rank)
      # Normalize rank to 0.0-1.0 (lower rank = better = higher score)
      # Log scale since ranks are heavily skewed (top cards cluster near 0)
      rank_score = 1.0 - (Math.log(rank + 1) / Math.log(max_rank + 1))

      # Blend: 70% role-match confidence, 30% EDHREC popularity
      data[:score] = (data[:score] * 0.7) + (rank_score * data[:score] * 0.3)
    end
  end
end
