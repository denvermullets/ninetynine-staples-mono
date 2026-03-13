module CommanderSpellbook
  class FindCombos < Service
    API_URL = 'https://backend.commanderspellbook.com/find-my-combos'.freeze
    TIMEOUT = 30

    def initialize(card_names:, commanders: [])
      @card_names = card_names
      @commanders = commanders
      @card_names_set = card_names.to_set(&:downcase)
    end

    def call
      log "Sending #{@card_names.size} cards, #{@commanders.size} commanders to Spellbook"

      response = post_to_spellbook
      log "Response code: #{response.code}"

      return api_error(response) unless response.success?

      results = response.parsed_response['results'] || {}
      result = parse_response(results)
      log "Parsed: #{result[:included].size} included, #{result[:almost_included].size} almost_included"
      result
    rescue Net::OpenTimeout, Net::ReadTimeout
      log 'TIMEOUT'
      { error: 'Commander Spellbook request timed out' }
    rescue StandardError => e
      log "ERROR: #{e.class}: #{e.message}"
      { error: "Commander Spellbook error: #{e.message}" }
    end

    private

    def log(message) = Rails.logger.info("[FindCombos] #{message}")

    def api_error(response)
      log "API error! Body: #{response.body[0..500]}"
      { error: "API error: #{response.code}" }
    end

    def post_to_spellbook
      HTTParty.post(
        API_URL,
        body: request_body.to_json,
        headers: { 'Content-Type' => 'application/json' },
        timeout: TIMEOUT
      )
    end

    def request_body
      {
        main: @card_names.map { |name| { card: name } },
        commanders: @commanders.map { |name| { card: name } }
      }
    end

    def parse_response(results)
      included = results['included'] || []
      almost = results['almostIncluded'] || []

      {
        included: parse_combos(included, almost_included: false),
        almost_included: parse_combos(
          almost.select { |c| missing_cards_for(c).length <= 2 },
          almost_included: true
        )
      }
    end

    def parse_combos(combos, almost_included:)
      combos.filter_map { |c| parse_combo(c, almost_included: almost_included) }
    end

    def parse_combo(combo, almost_included:)
      {
        spellbook_id: combo['id']&.to_s,
        cards: parse_uses(combo),
        missing_cards: almost_included ? missing_cards_for(combo) : [],
        prerequisites: parse_prerequisites(combo),
        steps: combo['description'] || '',
        results: parse_results(combo),
        color_identity: combo['identity'] || '',
        permalink: "https://commanderspellbook.com/combo/#{combo['id']}",
        has_banned_card: combo.dig('legalities', 'commander') == 'Banned'
      }
    rescue StandardError => e
      log "Failed to parse combo #{combo['id']}: #{e.message}"
      nil
    end

    def parse_uses(combo)
      (combo['uses'] || []).map do |use|
        { name: use.dig('card', 'name'), oracle_id: use.dig('card', 'oracleId') }
      end
    end

    def parse_prerequisites(combo)
      %w[easyPrerequisites notablePrerequisites requires].flat_map do |key|
        Array(combo[key]).map { |p| p.is_a?(Hash) ? p.dig('template', 'name') : p.to_s }
      end.compact.reject(&:blank?).join("\n")
    end

    def parse_results(combo)
      Array(combo['produces']).filter_map do |p|
        p.is_a?(Hash) ? p.dig('feature', 'name') : p.to_s
      end.reject(&:blank?).join(', ')
    end

    def missing_cards_for(combo)
      (combo['uses'] || [])
        .reject { |use| @card_names_set.include?(use.dig('card', 'name')&.downcase) }
        .map { |use| { name: use.dig('card', 'name'), oracle_id: use.dig('card', 'oracleId') } }
    end
  end
end
