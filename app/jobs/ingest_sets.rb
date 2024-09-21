require "open-uri"

class IngestSets < ApplicationJob
  def perform
    puts "loading SetList.json from mtgjson.com"
    source = URI.open("https://mtgjson.com/api/v5/SetList.json")
    puts "completed loading SetList.json from mtgjson.com"
    all_info = JSON.parse(source.read)["data"]

    all_info.each do |set|
      # next unless set["code"] == "PSVC"
      next if set["code"] == "UST"

      puts "opening up #{set["name"]}"
      boxset = create_boxset(set)

      IngestSetCards.perform_later(set) if boxset
    end
  end

  def create_boxset(set)
    boxset = Boxset.find_by(code: set["code"]) ||
             Boxset.create(
               code: set["code"],
               name: set["name"],
               release_date: set["releaseDate"],
               base_set_size: set["baseSetSize"],
               total_set_size: set["totalSetSize"],
               set_type: set["type"],
               keyrune_code: set["keyruneCode"]
             )

    boxset.update(
      code: set["code"],
      name: set["name"],
      release_date: set["releaseDate"],
      base_set_size: set["baseSetSize"],
      total_set_size: set["totalSetSize"],
      set_type: set["type"],
      keyrune_code: set["keyruneCode"]
    )
  end
end
