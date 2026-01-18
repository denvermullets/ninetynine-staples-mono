module CommanderGames
  class SearchCommanders < Service
    def initialize(query:, limit: 20)
      @query = query.to_s.strip
      @limit = limit
    end

    def call
      return [] if @query.length < 2

      # Get the newest version of each commander (highest id per name)
      newest_ids = MagicCard
        .where(can_be_commander: true)
        .where('name ILIKE ?', "%#{@query}%")
        .group(:name)
        .select('MAX(id) as id')

      MagicCard
        .where(id: newest_ids)
        .select(:id, :name, :image_small)
        .order(:name)
        .limit(@limit)
    end
  end
end
