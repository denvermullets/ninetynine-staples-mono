# takes a row off a user's want list
module WantList
  class Remove < Service
    def initialize(item:)
      @item = item
    end

    def call
      name = @item.magic_card.name
      @item.destroy!

      { success: true, name: }
    end
  end
end
