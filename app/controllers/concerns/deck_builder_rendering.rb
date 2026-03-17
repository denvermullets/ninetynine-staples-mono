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

  def render_card_action_response(result, success_message:)
    return render_error_toast(result[:error]) unless result[:success]

    flash.now[:type] = 'success'
    set_deck_view_defaults
    invalidate_combo_data
    load_deck_cards
    load_combo_data
    render turbo_stream: card_action_streams(success_message)
  end

  def render_deck_cards_stream
    render turbo_stream: [
      turbo_stream.update('deck_cards', partial: 'deck_cards', locals: deck_cards_locals),
      turbo_stream.update('deck_stats', partial: 'deck_stats', locals: { stats: @stats }),
      turbo_stream.update('deck_bracket', partial: 'deck_bracket',
                                          locals: bracket_locals),
      turbo_stream.update('deck_violations', partial: 'violations', locals: violations_locals),
      turbo_stream.update('combo_actions', partial: 'combo_actions', locals: combo_actions_locals)
    ]
  end

  def combo_actions_locals
    {
      deck: @deck, is_owner: @is_owner,
      combos_checked_at: @combos_checked_at,
      combo_card_oracle_ids: @combo_card_oracle_ids
    }
  end

  def bracket_locals
    { bracket_result: @bracket_result, deck: @deck, is_owner: @is_owner,
      combo_count: @combo_count || 0 }
  end

  def violations_locals
    { violations_result: @violations_result }
  end

  def card_action_streams(success_message)
    [
      turbo_stream.update('deck_cards', partial: 'deck_cards', locals: deck_cards_locals),
      turbo_stream.update('deck_stats', partial: 'deck_stats', locals: { stats: @stats }),
      turbo_stream.update('deck_bracket', partial: 'deck_bracket', locals: bracket_locals),
      turbo_stream.update('deck_violations', partial: 'violations', locals: violations_locals),
      turbo_stream.update('combo_actions', partial: 'combo_actions', locals: combo_actions_locals),
      turbo_stream.update('header_actions', partial: 'header_actions',
                                            locals: { deck: @deck, is_owner: @is_owner }),
      turbo_stream.update('deck_modal', ''),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: success_message })
    ]
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
end
