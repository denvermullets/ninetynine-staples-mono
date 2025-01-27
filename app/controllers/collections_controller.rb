class CollectionsController < ApplicationController
  require 'pagy/extras/array'

  def show
    # case sensitive for now
    user = User.find_by(username: params[:username])

    # user could have many decks/binders, so grab full collection at first
    # later will filter by params

    if user.present?
      boxset_options(user)

      magic_cards = load_collection.magic_cards.includes(magic_card_color_idents: :color)
      @pagy, @magic_cards = pagy_array(magic_cards)

      respond_to do |format|
        format.turbo_stream
        format.html { render 'index' }
      end
    else
      render :not_found
    end
  end

  def load
    # collection = User.find_by(username: params[:username]).collections.first
    magic_cards = Search::Collection.call(
      collection: load_collection, search_term: params[:search], code: params[:code]
    )
    @pagy, @magic_cards = pagy_array(magic_cards)

    respond_to do |format|
      format.turbo_stream
      format.html { render :index }
    end
  end

  def fetch_boxset(code)
    return if code.nil?

    Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: code)
  end

  def boxset_options(user)
    # just get the boxset_id's for cards in the collection and create the options list from that
    boxset_ids = user.collections.first.magic_cards.pluck(:boxset_id).uniq.compact
    boxsets = Boxset.where(id: boxset_ids)
    @options = boxsets.map do |boxset|
      { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase }
    end
  end

  private

  def load_collection
    if params[:collection_id].present?
      Collection.find(params[:collection_id])
    else
      User.find_by(username: params[:username]).collections.first
    end
  end
end
