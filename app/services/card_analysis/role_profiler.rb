module CardAnalysis
  class RoleProfiler < Service
    def initialize(scryfall_oracle_id:, oracle_text:, card_type:, **options)
      @scryfall_oracle_id = scryfall_oracle_id
      @oracle_text = (oracle_text || '').downcase
      @card_type = (card_type || '').downcase
      @keywords = (options[:keywords] || []).map(&:downcase)
      @subtypes = (options[:subtypes] || []).map(&:downcase)
      @layout = options[:layout]
      @power = options[:power]
    end

    def call
      results = {}

      OracleTextDetector.new(@oracle_text, @card_type).detect(results)
      detect_keyword_roles(results)
      detect_type_line_roles(results)
      detect_land_subtypes(results)

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
        'indestructible' => { role: 'protection', effect: 'indestructible_grant', confidence: 0.5 },
        'mill' => { role: 'mill', effect: 'mill', confidence: 0.5 },
        'double strike' => { role: 'voltron', effect: 'double_strike', confidence: 0.5 }
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

    def detect_land_subtypes(results)
      return unless @card_type.include?('land')

      detect_land_by_basic_types(results)
      detect_mdfc_land(results)
    end

    def detect_land_by_basic_types(results)
      basic_types = %w[plains island swamp mountain forest]
      land_basics = @subtypes & basic_types

      if land_basics.size >= 3
        add_result(results, role: 'manabase', effect: 'tri_land', confidence: 0.9, source: 'subtype')
      elsif land_basics.size >= 2
        add_result(results, role: 'manabase', effect: 'dual_land', confidence: 0.9, source: 'subtype')
      end

      return unless land_basics.size == 1 && @card_type.include?('basic')

      add_result(results, role: 'manabase', effect: 'basic_land', confidence: 0.95, source: 'subtype')
    end

    def detect_mdfc_land(results)
      return unless @layout == 'modal_dfc'

      add_result(results, role: 'manabase', effect: 'mdfc_land', confidence: 0.85, source: 'type')
    end

    def add_result(results, role:, effect:, confidence:, source:)
      key = [role, effect]
      existing = results[key]
      return unless existing.nil? || confidence > existing[:confidence]

      results[key] = { role: role, effect: effect, confidence: confidence, source: source }
    end
  end
end
