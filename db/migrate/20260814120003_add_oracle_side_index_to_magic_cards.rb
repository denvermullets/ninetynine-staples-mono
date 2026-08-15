# (scryfall_oracle_id, card_side) is the predicate every card-analysis service uses - ReplacementFinder,
# EdhrecRankBlender, ColorIdentityGate and CommanderSynergy all narrow to "one printing per oracle id,
# front face only" - but only scryfall_oracle_id is indexed, so the card_side filter is a heap recheck on
# every matching printing.
#
# Measured on the dev DB: ColorIdentityGate's representative_card_ids over a 10,641-oracle-id candidate
# set took 467ms of the ~1.1s suggestion pipeline.
#
# Concurrently, because magic_cards is read on nearly every request.
class AddOracleSideIndexToMagicCards < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :magic_cards, %i[scryfall_oracle_id card_side], algorithm: :concurrently
  end
end
