module CardAnalysis
  class RoleProfiler < Service
    def initialize(scryfall_oracle_id:, oracle_text:, card_type:, **options)
      @scryfall_oracle_id = scryfall_oracle_id
      @oracle_text = (oracle_text || '').downcase
      @card_type = (card_type || '').downcase
      @keywords = (options[:keywords] || []).map(&:downcase)
      @power = options[:power]
    end

    def call
      results = {}

      OracleTextDetector.new(@oracle_text, @card_type).detect(results)
      detect_keyword_roles(results)
      detect_type_line_roles(results)

      results.values
    end

    private

    def detect_keyword_roles(results)
      keyword_map = {
        'flying' => { role: 'evasion', effect: 'flying_grant', confidence: 0.4 },
        'trample' => { role: 'evasion', effect: 'trample_grant', confidence: 0.4 },
        'menace' => { role: 'evasion', effect: 'menace_grant', confidence: 0.4 },
        'lifelink' => { role: 'lifegain', effect: 'life_gain', confidence: 0.4 },
        'ward' => { role: 'protection', effect: 'ward_grant', confidence: 0.5 },
        'hexproof' => { role: 'protection', effect: 'hexproof_grant', confidence: 0.5 },
        'indestructible' => { role: 'protection', effect: 'indestructible_grant', confidence: 0.5 }
      }

      @keywords.each do |kw|
        mapping = keyword_map[kw]
        next unless mapping

        add_result(results, role: mapping[:role], effect: mapping[:effect],
                            confidence: mapping[:confidence], source: 'keyword')
      end
    end

    def detect_type_line_roles(results)
      if @card_type.include?('equipment')
        add_result(results, role: 'pump', effect: 'equipment', confidence: 0.8, source: 'type')
      end

      if @card_type.include?('aura') && @oracle_text.match?(/enchant creature/)
        add_result(results, role: 'pump', effect: 'aura_buff', confidence: 0.75, source: 'type')
      end

      return unless @card_type.include?('creature') && @power.to_i >= 6

      add_result(results, role: 'finisher', effect: 'big_beater', confidence: 0.6, source: 'type')
    end

    def add_result(results, role:, effect:, confidence:, source:)
      key = [role, effect]
      existing = results[key]
      return unless existing.nil? || confidence > existing[:confidence]

      results[key] = { role: role, effect: effect, confidence: confidence, source: source }
    end
  end
end
