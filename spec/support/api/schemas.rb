require 'json_schemer'

# Validates /api/v1 responses against the JSON Schemas in spec/support/schemas, the machine-checked half of
# the API contract (docs/api/v1.md is the prose half). Used by the request specs through the matchers
# below, and by the api:export_fixtures task so an exported fixture always matches its schema.
module ApiSchemas
  DIR = Rails.root.join('spec/support/schemas')

  module_function

  def names
    DIR.glob('*.json').map { |path| path.basename('.json').to_s }.sort
  end

  # error messages for data against schema `name`, [] when it matches. `page_of:` validates a list
  # endpoint's page envelope (page.json) plus every item in data against that schema instead
  def errors(data, name = nil, page_of: nil)
    return schema(name).validate(data).map { |error| error['error'] }.to_a unless page_of

    items = data.is_a?(Hash) ? Array(data['data']) : []
    item_errors = items.each_with_index.flat_map do |item, index|
      errors(item, page_of).map { |message| "data/#{index}: #{message}" }
    end
    errors(data, 'page') + item_errors
  end

  def schema(name)
    @schemas ||= {}
    @schemas[name.to_s] ||= begin
      path = DIR.join("#{name}.json")
      raise ArgumentError, "No API schema #{path}" unless path.exist?

      JSONSchemer.schema(path)
    end
  end
end

return unless defined?(RSpec::Matchers)

# expect(json_body).to match_api_schema(:deck)
RSpec::Matchers.define :match_api_schema do |name|
  match { |data| (@errors = ApiSchemas.errors(data, name)).empty? }
  failure_message { "expected the response to match #{name}.json:\n  #{@errors.first(10).join("\n  ")}" }
end

# expect(json_body).to match_api_page_of(:deck_summary)
RSpec::Matchers.define :match_api_page_of do |name|
  match { |data| (@errors = ApiSchemas.errors(data, page_of: name)).empty? }
  failure_message { "expected a page of #{name}.json:\n  #{@errors.first(10).join("\n  ")}" }
end
