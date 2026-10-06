# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_06_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.string "name", null: false
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "artists", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "boxsets", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.date "release_date"
    t.integer "base_set_size"
    t.integer "total_set_size"
    t.string "set_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "valid_cards", default: false, null: false
    t.string "keyrune_code"
    t.jsonb "value_history", default: {"foil" => [], "normal" => []}
  end

  create_table "brackets", force: :cascade do |t|
    t.integer "level", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["level"], name: "index_brackets_on_level", unique: true
  end

  create_table "card_oracle_tags", force: :cascade do |t|
    t.bigint "oracle_tag_id", null: false
    t.uuid "scryfall_oracle_id", null: false
    t.string "weight"
    t.text "annotation"
    t.string "source", default: "scryfall", null: false
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["oracle_tag_id", "scryfall_oracle_id", "source"], name: "idx_card_oracle_tags_unique", unique: true
    t.index ["scryfall_oracle_id"], name: "index_card_oracle_tags_on_scryfall_oracle_id"
    t.index ["user_id"], name: "index_card_oracle_tags_on_user_id"
  end

  create_table "card_prices", force: :cascade do |t|
    t.bigint "magic_card_id"
    t.string "mtg_uuid"
    t.jsonb "price_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_card_prices_on_magic_card_id"
  end

  create_table "card_roles", force: :cascade do |t|
    t.string "scryfall_oracle_id", null: false
    t.string "role", null: false
    t.string "effect", null: false
    t.float "confidence", default: 1.0, null: false
    t.string "source", default: "pattern", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role", "effect"], name: "index_card_roles_on_role_and_effect"
    t.index ["role"], name: "index_card_roles_on_role"
    t.index ["scryfall_oracle_id", "role", "effect"], name: "idx_card_roles_unique", unique: true
    t.index ["scryfall_oracle_id"], name: "index_card_roles_on_scryfall_oracle_id"
  end

  create_table "card_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "collection_magic_cards", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.bigint "magic_card_id", null: false
    t.string "card_uuid"
    t.integer "foil_quantity", default: 0
    t.integer "quantity", default: 0
    t.decimal "buy_price", precision: 12, scale: 2, default: "0.0"
    t.decimal "sell_price", precision: 12, scale: 2, default: "0.0"
    t.string "condition"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "proxy_quantity", default: 0, null: false
    t.integer "proxy_foil_quantity", default: 0, null: false
    t.boolean "staged", default: false, null: false
    t.bigint "source_collection_id"
    t.integer "staged_quantity", default: 0, null: false
    t.integer "staged_foil_quantity", default: 0, null: false
    t.boolean "needed", default: false, null: false
    t.string "board_type", default: "mainboard"
    t.integer "staged_proxy_quantity", default: 0, null: false
    t.integer "staged_proxy_foil_quantity", default: 0, null: false
    t.integer "trade_quantity", default: 0, null: false
    t.integer "trade_foil_quantity", default: 0, null: false
    t.index ["board_type"], name: "index_collection_magic_cards_on_board_type"
    t.index ["collection_id", "staged", "needed"], name: "index_cmc_on_collection_staged_needed", include: ["magic_card_id"]
    t.index ["collection_id"], name: "index_collection_magic_cards_on_collection_id"
    t.index ["magic_card_id"], name: "index_collection_magic_cards_on_magic_card_id"
    t.index ["needed"], name: "index_collection_magic_cards_on_needed"
    t.index ["source_collection_id"], name: "index_collection_magic_cards_on_source_collection_id"
    t.index ["staged"], name: "index_collection_magic_cards_on_staged"
  end

  create_table "collection_tags", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id", "tag_id"], name: "index_collection_tags_on_collection_id_and_tag_id", unique: true
    t.index ["collection_id"], name: "index_collection_tags_on_collection_id"
    t.index ["tag_id"], name: "index_collection_tags_on_tag_id"
  end

  create_table "collections", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "collection_type"
    t.decimal "total_value", precision: 15, scale: 2, default: "0.0"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "total_foil_quantity", default: 0
    t.integer "total_quantity", default: 0
    t.jsonb "collection_history", default: {}
    t.integer "total_proxy_quantity", default: 0, null: false
    t.integer "total_proxy_foil_quantity", default: 0, null: false
    t.decimal "proxy_total_value", precision: 15, scale: 2, default: "0.0", null: false
    t.boolean "is_public", default: true, null: false
    t.bigint "cover_card_id"
    t.datetime "combos_checked_at"
    t.integer "bracket_level"
    t.index ["bracket_level"], name: "index_collections_on_bracket_level"
    t.index ["cover_card_id"], name: "index_collections_on_cover_card_id"
    t.index ["user_id"], name: "index_collections_on_user_id"
  end

  create_table "colors", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "combo_cards", force: :cascade do |t|
    t.bigint "combo_id", null: false
    t.string "card_name", null: false
    t.uuid "oracle_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["combo_id"], name: "index_combo_cards_on_combo_id"
    t.index ["oracle_id"], name: "index_combo_cards_on_oracle_id"
  end

  create_table "combos", force: :cascade do |t|
    t.string "spellbook_id", null: false
    t.text "prerequisites"
    t.text "steps"
    t.text "results"
    t.string "color_identity"
    t.string "permalink"
    t.boolean "has_banned_card", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["spellbook_id"], name: "index_combos_on_spellbook_id", unique: true
  end

  create_table "commander_games", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "tracked_deck_id", null: false
    t.date "played_on", null: false
    t.boolean "won", default: false, null: false
    t.integer "turn_ended_on"
    t.integer "pod_size", default: 4
    t.integer "bracket_level"
    t.integer "fun_rating"
    t.integer "performance_rating"
    t.string "win_condition"
    t.text "how_won"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bracket_level"], name: "index_commander_games_on_bracket_level"
    t.index ["played_on"], name: "index_commander_games_on_played_on"
    t.index ["tracked_deck_id"], name: "index_commander_games_on_tracked_deck_id"
    t.index ["user_id", "played_on"], name: "index_commander_games_on_user_id_and_played_on"
    t.index ["user_id"], name: "index_commander_games_on_user_id"
    t.index ["won"], name: "index_commander_games_on_won"
  end

  create_table "deck_combo_missing_cards", force: :cascade do |t|
    t.bigint "deck_combo_id", null: false
    t.string "card_name", null: false
    t.uuid "oracle_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deck_combo_id"], name: "index_deck_combo_missing_cards_on_deck_combo_id"
  end

  create_table "deck_combos", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.bigint "combo_id", null: false
    t.string "combo_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id", "combo_id"], name: "index_deck_combos_on_collection_id_and_combo_id", unique: true
    t.index ["collection_id"], name: "index_deck_combos_on_collection_id"
    t.index ["combo_id"], name: "index_deck_combos_on_combo_id"
  end

  create_table "deck_rules", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "rule_type", null: false
    t.integer "value", null: false
    t.bigint "bracket_id"
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "applies_to", default: "all", null: false
    t.index ["bracket_id"], name: "index_deck_rules_on_bracket_id"
    t.index ["rule_type", "applies_to", "bracket_id"], name: "index_deck_rules_on_type_applies_to_bracket", unique: true
  end

  create_table "finishes", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_finishes_on_name", unique: true
  end

  create_table "follows", force: :cascade do |t|
    t.bigint "follower_id", null: false
    t.bigint "followed_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["followed_id"], name: "index_follows_on_followed_id"
    t.index ["follower_id", "followed_id"], name: "index_follows_on_follower_id_and_followed_id", unique: true
  end

  create_table "frame_effects", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_frame_effects_on_name", unique: true
  end

  create_table "game_changers", force: :cascade do |t|
    t.uuid "oracle_id", null: false
    t.string "card_name", null: false
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["oracle_id"], name: "index_game_changers_on_oracle_id", unique: true
  end

  create_table "game_opponents", force: :cascade do |t|
    t.bigint "commander_game_id", null: false
    t.bigint "commander_id", null: false
    t.bigint "partner_commander_id"
    t.boolean "won", default: false
    t.string "win_condition"
    t.text "how_won"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commander_game_id"], name: "index_game_opponents_on_commander_game_id"
    t.index ["commander_id"], name: "index_game_opponents_on_commander_id"
    t.index ["partner_commander_id"], name: "index_game_opponents_on_partner_commander_id"
    t.index ["win_condition"], name: "index_game_opponents_on_win_condition"
    t.index ["won"], name: "index_game_opponents_on_won"
  end

  create_table "keywords", force: :cascade do |t|
    t.string "keyword"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "legalities", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_legalities_on_name", unique: true
  end

  create_table "magic_card_artists", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.bigint "artist_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_magic_card_artists_on_artist_id"
    t.index ["magic_card_id"], name: "index_magic_card_artists_on_magic_card_id"
  end

  create_table "magic_card_color_idents", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.bigint "color_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["color_id"], name: "index_magic_card_color_idents_on_color_id"
    t.index ["magic_card_id"], name: "index_magic_card_color_idents_on_magic_card_id"
  end

  create_table "magic_card_colors", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.bigint "color_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["color_id"], name: "index_magic_card_colors_on_color_id"
    t.index ["magic_card_id"], name: "index_magic_card_colors_on_magic_card_id"
  end

  create_table "magic_card_finishes", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.bigint "finish_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["finish_id"], name: "index_magic_card_finishes_on_finish_id"
    t.index ["magic_card_id", "finish_id"], name: "index_magic_card_finishes_on_magic_card_id_and_finish_id", unique: true
    t.index ["magic_card_id"], name: "index_magic_card_finishes_on_magic_card_id"
  end

  create_table "magic_card_frame_effects", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.bigint "frame_effect_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["frame_effect_id"], name: "index_magic_card_frame_effects_on_frame_effect_id"
    t.index ["magic_card_id", "frame_effect_id"], name: "idx_on_magic_card_id_frame_effect_id_83bcab9345", unique: true
    t.index ["magic_card_id"], name: "index_magic_card_frame_effects_on_magic_card_id"
  end

  create_table "magic_card_identifiers", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.string "abu_id"
    t.string "card_kingdom_etched_id"
    t.string "card_kingdom_foil_id"
    t.string "card_kingdom_id"
    t.string "cardsphere_foil_id"
    t.string "cardsphere_id"
    t.string "cardtrader_id"
    t.string "csi_id"
    t.string "mcm_id"
    t.string "mcm_meta_id"
    t.string "miniaturemarket_id"
    t.string "mtg_arena_id"
    t.string "mtgjson_foil_version_id"
    t.string "mtgjson_non_foil_version_id"
    t.string "mtgjson_v4_id"
    t.string "mtgo_foil_id"
    t.string "mtgo_id"
    t.string "multiverse_id"
    t.string "scg_id"
    t.string "scryfall_card_back_id"
    t.string "scryfall_id"
    t.string "scryfall_illustration_id"
    t.string "scryfall_oracle_id"
    t.string "tcgplayer_alternative_foil_product_id"
    t.string "tcgplayer_etched_product_id"
    t.string "tcgplayer_product_id"
    t.string "tnt_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_magic_card_identifiers_on_magic_card_id", unique: true
    t.index ["multiverse_id"], name: "index_magic_card_identifiers_on_multiverse_id"
    t.index ["scryfall_id"], name: "index_magic_card_identifiers_on_scryfall_id"
  end

  create_table "magic_card_keywords", force: :cascade do |t|
    t.bigint "magic_card_id"
    t.bigint "keyword_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["keyword_id"], name: "index_magic_card_keywords_on_keyword_id"
    t.index ["magic_card_id"], name: "index_magic_card_keywords_on_magic_card_id"
  end

  create_table "magic_card_legalities", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.bigint "legality_id", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["legality_id"], name: "index_magic_card_legalities_on_legality_id"
    t.index ["magic_card_id", "legality_id"], name: "index_magic_card_legalities_on_magic_card_id_and_legality_id", unique: true
    t.index ["magic_card_id"], name: "index_magic_card_legalities_on_magic_card_id"
    t.index ["status"], name: "index_magic_card_legalities_on_status"
  end

  create_table "magic_card_rulings", force: :cascade do |t|
    t.bigint "magic_card_id"
    t.bigint "ruling_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_magic_card_rulings_on_magic_card_id"
    t.index ["ruling_id"], name: "index_magic_card_rulings_on_ruling_id"
  end

  create_table "magic_card_sub_types", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.bigint "sub_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_magic_card_sub_types_on_magic_card_id"
    t.index ["sub_type_id"], name: "index_magic_card_sub_types_on_sub_type_id"
  end

  create_table "magic_card_super_types", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.bigint "super_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_magic_card_super_types_on_magic_card_id"
    t.index ["super_type_id"], name: "index_magic_card_super_types_on_super_type_id"
  end

  create_table "magic_card_types", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.bigint "card_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_type_id"], name: "index_magic_card_types_on_card_type_id"
    t.index ["magic_card_id"], name: "index_magic_card_types_on_magic_card_id"
  end

  create_table "magic_card_variations", force: :cascade do |t|
    t.bigint "magic_card_id", null: false
    t.bigint "variation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id", "variation_id"], name: "index_magic_card_variations_on_magic_card_id_and_variation_id", unique: true
    t.index ["magic_card_id"], name: "index_magic_card_variations_on_magic_card_id"
    t.index ["variation_id"], name: "index_magic_card_variations_on_variation_id"
  end

  create_table "magic_cards", force: :cascade do |t|
    t.bigint "boxset_id"
    t.string "name"
    t.string "text"
    t.string "original_text"
    t.string "power"
    t.string "toughness"
    t.string "rarity"
    t.string "card_type"
    t.string "original_type"
    t.integer "edhrec_rank"
    t.string "border_color"
    t.decimal "converted_mana_cost", precision: 10, scale: 2
    t.string "flavor_text"
    t.string "frame_version"
    t.boolean "is_reprint"
    t.string "card_number"
    t.string "card_uuid"
    t.string "image_large"
    t.string "image_medium"
    t.string "image_small"
    t.decimal "mana_value", precision: 10, scale: 2
    t.string "mana_cost"
    t.string "face_name"
    t.string "card_side"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "other_face_uuid"
    t.decimal "normal_price", precision: 12, scale: 2, default: "0.0"
    t.decimal "foil_price", precision: 12, scale: 2, default: "0.0"
    t.jsonb "price_history"
    t.string "art_crop"
    t.datetime "image_updated_at"
    t.decimal "price_change_weekly_normal", precision: 10, scale: 2
    t.decimal "price_change_weekly_foil", precision: 10, scale: 2
    t.boolean "is_token", default: false, null: false
    t.decimal "edhrec_saltiness"
    t.string "layout"
    t.string "security_stamp"
    t.boolean "can_be_commander", default: false
    t.boolean "can_be_brawl_commander", default: false
    t.boolean "can_be_oathbreaker_commander", default: false
    t.uuid "scryfall_oracle_id"
    t.decimal "ck_buylist_normal_price", precision: 12, scale: 2, default: "0.0"
    t.decimal "ck_buylist_foil_price", precision: 12, scale: 2, default: "0.0"
    t.boolean "is_reserved", default: false, null: false
    t.string "flavor_name"
    t.string "loyalty"
    t.string "defense"
    t.decimal "price_change_daily_normal", precision: 10, scale: 2
    t.decimal "price_change_daily_foil", precision: 10, scale: 2
    t.index "lower((face_name)::text)", name: "index_magic_cards_on_lower_face_name"
    t.index "lower((flavor_name)::text)", name: "index_magic_cards_on_lower_flavor_name"
    t.index "lower((name)::text)", name: "index_magic_cards_on_lower_name"
    t.index ["boxset_id"], name: "index_magic_cards_on_boxset_id"
    t.index ["can_be_commander", "boxset_id"], name: "index_magic_cards_on_can_be_commander_and_boxset_id"
    t.index ["can_be_commander"], name: "index_magic_cards_on_can_be_commander"
    t.index ["card_side"], name: "index_magic_cards_on_card_side"
    t.index ["edhrec_rank"], name: "index_magic_cards_on_edhrec_rank"
    t.index ["name"], name: "index_magic_cards_on_name"
    t.index ["price_change_daily_foil"], name: "index_magic_cards_on_price_change_daily_foil"
    t.index ["price_change_daily_normal"], name: "index_magic_cards_on_price_change_daily_normal"
    t.index ["price_change_weekly_foil"], name: "index_magic_cards_on_price_change_weekly_foil"
    t.index ["price_change_weekly_normal"], name: "index_magic_cards_on_price_change_weekly_normal"
    t.index ["rarity"], name: "index_magic_cards_on_rarity"
    t.index ["scryfall_oracle_id", "card_side"], name: "index_magic_cards_on_scryfall_oracle_id_and_card_side"
    t.index ["scryfall_oracle_id"], name: "index_magic_cards_on_scryfall_oracle_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.string "kind", null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
  end

  create_table "oracle_tag_ancestors", force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "depth", null: false
    t.index ["ancestor_id"], name: "index_oracle_tag_ancestors_on_ancestor_id"
    t.index ["descendant_id", "ancestor_id"], name: "index_oracle_tag_ancestors_on_descendant_id_and_ancestor_id", unique: true
  end

  create_table "oracle_tags", force: :cascade do |t|
    t.uuid "scryfall_id"
    t.string "slug", null: false
    t.string "label", null: false
    t.text "description"
    t.string "aliases", default: [], null: false, array: true
    t.string "source", default: "scryfall", null: false
    t.boolean "disabled", default: false, null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_oracle_tags_on_created_by_id"
    t.index ["scryfall_id"], name: "index_oracle_tags_on_scryfall_id", unique: true
    t.index ["slug"], name: "index_oracle_tags_on_slug", unique: true
  end

  create_table "precon_deck_cards", force: :cascade do |t|
    t.bigint "precon_deck_id", null: false
    t.bigint "magic_card_id", null: false
    t.integer "quantity", default: 1
    t.string "board_type", null: false
    t.boolean "is_foil", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_precon_deck_cards_on_magic_card_id"
    t.index ["precon_deck_id", "magic_card_id", "board_type"], name: "idx_precon_deck_cards_unique", unique: true
    t.index ["precon_deck_id"], name: "index_precon_deck_cards_on_precon_deck_id"
  end

  create_table "precon_decks", force: :cascade do |t|
    t.string "code", null: false
    t.string "file_name", null: false
    t.string "name", null: false
    t.date "release_date"
    t.string "deck_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_precon_decks_on_code"
    t.index ["deck_type"], name: "index_precon_decks_on_deck_type"
    t.index ["file_name"], name: "index_precon_decks_on_file_name", unique: true
  end

  create_table "price_alerts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "kind", null: false
    t.bigint "magic_card_id"
    t.uuid "scryfall_oracle_id"
    t.bigint "collection_id"
    t.string "finish", default: "any", null: false
    t.string "direction", null: false
    t.decimal "threshold_price", precision: 10, scale: 2
    t.string "window"
    t.decimal "min_delta_amount", precision: 10, scale: 2
    t.decimal "min_delta_percent", precision: 10, scale: 2
    t.decimal "min_price", precision: 10, scale: 2
    t.string "last_side"
    t.datetime "last_fired_at"
    t.date "last_evaluated_on"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "min_buylist_price", precision: 10, scale: 2
    t.decimal "max_buylist_price", precision: 10, scale: 2
    t.decimal "from_price", precision: 10, scale: 2
    t.string "rarities", default: [], null: false, array: true
    t.index ["collection_id"], name: "index_price_alerts_on_collection_id"
    t.index ["magic_card_id"], name: "index_price_alerts_on_magic_card_id"
    t.index ["scryfall_oracle_id"], name: "index_price_alerts_on_scryfall_oracle_id"
    t.index ["user_id", "active"], name: "index_price_alerts_on_user_id_and_active"
    t.index ["user_id", "magic_card_id", "window"], name: "index_price_alerts_on_card_override", unique: true, where: "(((kind)::text = 'movement'::text) AND (magic_card_id IS NOT NULL))"
  end

  create_table "price_band_cards", force: :cascade do |t|
    t.bigint "price_alert_id", null: false
    t.bigint "magic_card_id", null: false
    t.string "finish", null: false
    t.string "state", null: false
    t.date "crossed_on"
    t.decimal "crossed_price", precision: 10, scale: 2
    t.string "moved"
    t.datetime "handled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_price_band_cards_on_magic_card_id"
    t.index ["price_alert_id", "magic_card_id", "finish"], name: "index_price_band_cards_on_band_card_finish", unique: true
  end

  create_table "printings", force: :cascade do |t|
    t.bigint "magic_card_id"
    t.string "boxset_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_printings_on_magic_card_id"
  end

  create_table "rulings", force: :cascade do |t|
    t.date "ruling_date"
    t.string "ruling"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scryfall_bulk_imports", force: :cascade do |t|
    t.string "bulk_type", null: false
    t.datetime "remote_updated_at"
    t.datetime "imported_at"
    t.integer "tag_count"
    t.integer "tagging_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bulk_type"], name: "index_scryfall_bulk_imports_on_bulk_type", unique: true
  end

  create_table "sub_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "super_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "#6366f1"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "tracked_decks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "commander_id", null: false
    t.bigint "partner_commander_id"
    t.string "name", null: false
    t.text "notes"
    t.string "status", default: "active"
    t.date "last_tweaked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "collection_id"
    t.index ["collection_id"], name: "index_tracked_decks_on_collection_id"
    t.index ["commander_id"], name: "index_tracked_decks_on_commander_id"
    t.index ["partner_commander_id"], name: "index_tracked_decks_on_partner_commander_id"
    t.index ["status"], name: "index_tracked_decks_on_status"
    t.index ["user_id", "name"], name: "index_tracked_decks_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tracked_decks_on_user_id"
  end

  create_table "trade_events", force: :cascade do |t|
    t.bigint "trade_id", null: false
    t.bigint "user_id"
    t.string "event", null: false
    t.datetime "created_at", null: false
    t.index ["trade_id"], name: "index_trade_events_on_trade_id"
    t.index ["user_id"], name: "index_trade_events_on_user_id"
  end

  create_table "trade_items", force: :cascade do |t|
    t.bigint "trade_id", null: false
    t.bigint "collection_magic_card_id"
    t.bigint "magic_card_id", null: false
    t.string "side", null: false
    t.integer "quantity", default: 0, null: false
    t.integer "foil_quantity", default: 0, null: false
    t.decimal "unit_price_snapshot", precision: 12, scale: 2, default: "0.0"
    t.decimal "unit_foil_price_snapshot", precision: 12, scale: 2, default: "0.0"
    t.decimal "unit_buylist_snapshot", precision: 12, scale: 2, default: "0.0"
    t.decimal "unit_buylist_foil_snapshot", precision: 12, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "off_list", default: false, null: false
    t.index ["collection_magic_card_id"], name: "index_trade_items_on_collection_magic_card_id"
    t.index ["magic_card_id"], name: "index_trade_items_on_magic_card_id"
    t.index ["trade_id", "side"], name: "index_trade_items_on_trade_id_and_side"
    t.index ["trade_id"], name: "index_trade_items_on_trade_id"
  end

  create_table "trades", force: :cascade do |t|
    t.bigint "proposer_id", null: false
    t.bigint "recipient_id", null: false
    t.bigint "parent_trade_id"
    t.string "status", default: "proposed", null: false
    t.text "message"
    t.datetime "proposer_completed_at"
    t.datetime "recipient_completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_trade_id"], name: "index_trades_on_parent_trade_id"
    t.index ["proposer_id", "status"], name: "index_trades_on_proposer_id_and_status"
    t.index ["proposer_id"], name: "index_trades_on_proposer_id"
    t.index ["recipient_id", "status"], name: "index_trades_on_recipient_id_and_status"
    t.index ["recipient_id"], name: "index_trades_on_recipient_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "username", null: false
    t.string "role", default: "1001", null: false
    t.datetime "confirmed_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "prices_last_updated_at"
    t.jsonb "preferences", default: {}
    t.boolean "game_tracker_public", default: false, null: false
    t.boolean "trades_public", default: false, null: false
    t.boolean "wants_public", default: false, null: false
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "want_list_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "magic_card_id", null: false
    t.uuid "scryfall_oracle_id"
    t.boolean "any_printing", default: true, null: false
    t.integer "quantity", default: 1, null: false
    t.string "foil_preference", default: "any", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_want_list_items_on_magic_card_id"
    t.index ["scryfall_oracle_id"], name: "index_want_list_items_on_scryfall_oracle_id"
    t.index ["user_id", "magic_card_id"], name: "index_want_list_items_on_user_id_and_magic_card_id", unique: true
    t.index ["user_id", "scryfall_oracle_id"], name: "index_want_list_items_on_user_and_oracle_any_printing", unique: true, where: "any_printing"
  end

  add_foreign_key "api_tokens", "users"
  add_foreign_key "card_oracle_tags", "oracle_tags"
  add_foreign_key "card_oracle_tags", "users"
  add_foreign_key "collection_magic_cards", "collections"
  add_foreign_key "collection_magic_cards", "collections", column: "source_collection_id"
  add_foreign_key "collection_magic_cards", "magic_cards"
  add_foreign_key "collection_tags", "collections"
  add_foreign_key "collection_tags", "tags"
  add_foreign_key "collections", "magic_cards", column: "cover_card_id"
  add_foreign_key "collections", "users"
  add_foreign_key "combo_cards", "combos"
  add_foreign_key "commander_games", "tracked_decks"
  add_foreign_key "commander_games", "users"
  add_foreign_key "deck_combo_missing_cards", "deck_combos"
  add_foreign_key "deck_combos", "collections"
  add_foreign_key "deck_combos", "combos"
  add_foreign_key "deck_rules", "brackets"
  add_foreign_key "follows", "users", column: "followed_id"
  add_foreign_key "follows", "users", column: "follower_id"
  add_foreign_key "game_opponents", "commander_games"
  add_foreign_key "game_opponents", "magic_cards", column: "commander_id"
  add_foreign_key "game_opponents", "magic_cards", column: "partner_commander_id"
  add_foreign_key "magic_card_finishes", "finishes"
  add_foreign_key "magic_card_finishes", "magic_cards"
  add_foreign_key "magic_card_frame_effects", "frame_effects"
  add_foreign_key "magic_card_frame_effects", "magic_cards"
  add_foreign_key "magic_card_identifiers", "magic_cards"
  add_foreign_key "magic_card_legalities", "legalities"
  add_foreign_key "magic_card_legalities", "magic_cards"
  add_foreign_key "magic_card_variations", "magic_cards"
  add_foreign_key "magic_card_variations", "magic_cards", column: "variation_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "oracle_tag_ancestors", "oracle_tags", column: "ancestor_id"
  add_foreign_key "oracle_tag_ancestors", "oracle_tags", column: "descendant_id"
  add_foreign_key "oracle_tags", "users", column: "created_by_id"
  add_foreign_key "precon_deck_cards", "magic_cards"
  add_foreign_key "precon_deck_cards", "precon_decks"
  add_foreign_key "price_alerts", "collections"
  add_foreign_key "price_alerts", "magic_cards"
  add_foreign_key "price_alerts", "users"
  add_foreign_key "price_band_cards", "magic_cards", on_delete: :cascade
  add_foreign_key "price_band_cards", "price_alerts", on_delete: :cascade
  add_foreign_key "tracked_decks", "collections"
  add_foreign_key "tracked_decks", "magic_cards", column: "commander_id"
  add_foreign_key "tracked_decks", "magic_cards", column: "partner_commander_id"
  add_foreign_key "tracked_decks", "users"
  add_foreign_key "trade_events", "trades"
  add_foreign_key "trade_events", "users"
  add_foreign_key "trade_items", "collection_magic_cards"
  add_foreign_key "trade_items", "magic_cards"
  add_foreign_key "trade_items", "trades"
  add_foreign_key "trades", "trades", column: "parent_trade_id"
  add_foreign_key "trades", "users", column: "proposer_id"
  add_foreign_key "trades", "users", column: "recipient_id"
  add_foreign_key "want_list_items", "magic_cards"
  add_foreign_key "want_list_items", "users"
end
