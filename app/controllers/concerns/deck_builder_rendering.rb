module DeckBuilderRendering
  extend ActiveSupport::Concern

  private

  def deck_cards_locals
    {
      grouped_cards: @grouped_cards, view_mode: @view_mode,
      is_owner: @is_owner, deck: @deck,
      combo_card_oracle_ids: @combo_card_oracle_ids, sort_by: @sort_by
    }
  end

  def render_card_action_response(result, success_message:, flash_type: 'success')
    return render_error_toast(result[:error]) unless result[:success]

    flash.now[:type] = flash_type
    set_deck_view_defaults
    invalidate_combos_for(result[:removed_oracle_id]) if result[:removed_oracle_id]
    load_deck_cards
    load_combo_data
    render turbo_stream: card_action_streams(success_message)
  end

  def render_deck_update_response(message, clear_modal: false)
    flash.now[:type] = 'success'
    set_deck_view_defaults
    load_deck_cards
    load_combo_data
    streams = deck_update_streams(message)
    streams << turbo_stream.update('deck_modal', '') if clear_modal
    render turbo_stream: streams
  end

  def render_deck_cards_stream
    render turbo_stream: deck_update_streams(nil).compact
  end

  def render_error_toast(message)
    flash.now[:type] = 'error'
    render turbo_stream: turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: message })
  end

  def handle_finalize_success(result)
    msg = "Deck finalized! #{result[:cards_moved]} cards moved"
    msg += ", #{result[:cards_needed]} cards needed" if result[:cards_needed].positive?
    redirect_to decks_index_path(username: current_user.username), notice: msg, status: :see_other
  end

  def handle_finalize_failure(result)
    load_deck_cards
    render turbo_stream: [
      turbo_stream.update('deck_cards', partial: 'deck_builder/deck_cards'),
      turbo_stream.update('deck_stats', partial: 'deck_builder/deck_stats'),
      turbo_stream.update('deck_modal', ''),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: result[:error], type: 'error' })
    ], status: :unprocessable_entity
  end

  def render_update_deck_success
    flash.now[:type] = 'success'
    @deck.reload
    render turbo_stream: [
      turbo_stream.update('deck-name', @deck.name),
      turbo_stream.update('deck-description', @deck.description),
      turbo_stream.replace('deck-tags', partial: 'deck_tags_wrapper', locals: { deck: @deck }),
      turbo_stream.update('deck_modal', ''),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: 'Deck updated successfully' })
    ]
  end

  def combo_actions_locals
    {
      deck: @deck, is_owner: @is_owner,
      combos_checked_at: @combos_checked_at,
      combo_card_oracle_ids: @combo_card_oracle_ids,
      deck_cards_changed: @deck_cards_changed
    }
  end

  def bracket_locals
    { bracket_result: @bracket_result, deck: @deck, is_owner: @is_owner,
      combo_count: @combo_count || 0 }
  end

  def violations_locals
    { violations_result: @violations_result }
  end

  def deck_update_streams(message)
    [
      turbo_stream.update('deck_cards', partial: 'deck_cards', locals: deck_cards_locals),
      turbo_stream.update('deck_stats', partial: 'deck_stats', locals: { stats: @stats }),
      turbo_stream.update('deck_bracket', partial: 'deck_bracket', locals: bracket_locals),
      turbo_stream.update('deck_violations', partial: 'violations', locals: violations_locals),
      turbo_stream.update('combo_actions', partial: 'combo_actions', locals: combo_actions_locals),
      (turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: message }) if message)
    ]
  end

  def card_action_streams(success_message)
    deck_update_streams(success_message) + [
      turbo_stream.update('header_actions', partial: 'header_actions',
                                            locals: { deck: @deck, is_owner: @is_owner }),
      turbo_stream.update('deck_modal', '')
    ]
  end
end
