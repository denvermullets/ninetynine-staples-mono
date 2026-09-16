# Turns a parent map into closure-table rows for oracle_tag_ancestors.
#
# The Tagger hierarchy is a DAG, not a tree - hundreds of tags have more than one parent - so each tag walks
# upward breadth-first and records the shortest distance to every ancestor. The visited check doubles as a
# cycle guard, since the data is community-edited.
module Scryfall
  class OracleTagClosure < Service
    # parents: { tag_id => [parent_tag_id, ...] } covering every tag, including ones with no parents
    def initialize(parents:)
      @parents = parents
    end

    # -> [{ ancestor_id:, descendant_id:, depth: }, ...], with a depth-0 row for every tag
    def call
      @parents.keys.flat_map do |tag_id|
        ancestor_depths(tag_id).map do |ancestor_id, depth|
          { ancestor_id: ancestor_id, descendant_id: tag_id, depth: depth }
        end
      end
    end

    private

    def ancestor_depths(tag_id)
      depths = { tag_id => 0 }
      frontier = [tag_id]
      level = 0

      until frontier.empty?
        level += 1
        frontier = frontier.flat_map { |id| @parents.fetch(id, []) }.uniq.reject { |id| depths.key?(id) }
        frontier.each { |id| depths[id] = level }
      end

      depths
    end
  end
end
