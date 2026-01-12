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

ActiveRecord::Schema[8.1].define(version: 2026_01_12_220000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "artists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "boxsets", force: :cascade do |t|
    t.integer "base_set_size"
    t.string "code"
    t.datetime "created_at", null: false
    t.string "keyrune_code"
    t.string "name"
    t.date "release_date"
    t.string "set_type"
    t.integer "total_set_size"
    t.datetime "updated_at", null: false
    t.boolean "valid_cards", default: false, null: false
    t.jsonb "value_history", default: {"foil"=>[], "normal"=>[]}
  end

  create_table "card_prices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "magic_card_id"
    t.string "mtg_uuid"
    t.jsonb "price_data"
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_card_prices_on_magic_card_id"
  end

  create_table "card_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "collection_magic_cards", force: :cascade do |t|
    t.string "board_type", default: "mainboard"
    t.decimal "buy_price", precision: 12, scale: 2, default: "0.0"
    t.string "card_uuid"
    t.bigint "collection_id", null: false
    t.string "condition"
    t.datetime "created_at", null: false
    t.integer "foil_quantity", default: 0
    t.bigint "magic_card_id", null: false
    t.boolean "needed", default: false, null: false
    t.text "notes"
    t.integer "proxy_foil_quantity", default: 0, null: false
    t.integer "proxy_quantity", default: 0, null: false
    t.integer "quantity", default: 0
    t.decimal "sell_price", precision: 12, scale: 2, default: "0.0"
    t.bigint "source_collection_id"
    t.boolean "staged", default: false, null: false
    t.integer "staged_foil_quantity", default: 0, null: false
    t.integer "staged_quantity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["board_type"], name: "index_collection_magic_cards_on_board_type"
    t.index ["collection_id"], name: "index_collection_magic_cards_on_collection_id"
    t.index ["magic_card_id"], name: "index_collection_magic_cards_on_magic_card_id"
    t.index ["needed"], name: "index_collection_magic_cards_on_needed"
    t.index ["source_collection_id"], name: "index_collection_magic_cards_on_source_collection_id"
    t.index ["staged"], name: "index_collection_magic_cards_on_staged"
  end

  create_table "collections", force: :cascade do |t|
    t.jsonb "collection_history", default: {}
    t.string "collection_type"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.decimal "proxy_total_value", precision: 15, scale: 2, default: "0.0", null: false
    t.integer "total_foil_quantity", default: 0
    t.integer "total_proxy_foil_quantity", default: 0, null: false
    t.integer "total_proxy_quantity", default: 0, null: false
    t.integer "total_quantity", default: 0
    t.decimal "total_value", precision: 15, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_collections_on_user_id"
  end

  create_table "colors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "keywords", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "keyword"
    t.datetime "updated_at", null: false
  end

  create_table "legalities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_legalities_on_name", unique: true
  end

  create_table "magic_card_artists", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.datetime "created_at", null: false
    t.bigint "magic_card_id", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_magic_card_artists_on_artist_id"
    t.index ["magic_card_id"], name: "index_magic_card_artists_on_magic_card_id"
  end

  create_table "magic_card_color_idents", force: :cascade do |t|
    t.bigint "color_id", null: false
    t.datetime "created_at", null: false
    t.bigint "magic_card_id", null: false
    t.datetime "updated_at", null: false
    t.index ["color_id"], name: "index_magic_card_color_idents_on_color_id"
    t.index ["magic_card_id"], name: "index_magic_card_color_idents_on_magic_card_id"
  end

  create_table "magic_card_colors", force: :cascade do |t|
    t.bigint "color_id", null: false
    t.datetime "created_at", null: false
    t.bigint "magic_card_id", null: false
    t.datetime "updated_at", null: false
    t.index ["color_id"], name: "index_magic_card_colors_on_color_id"
    t.index ["magic_card_id"], name: "index_magic_card_colors_on_magic_card_id"
  end

  create_table "magic_card_keywords", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "keyword_id"
    t.bigint "magic_card_id"
    t.datetime "updated_at", null: false
    t.index ["keyword_id"], name: "index_magic_card_keywords_on_keyword_id"
    t.index ["magic_card_id"], name: "index_magic_card_keywords_on_magic_card_id"
  end

  create_table "magic_card_legalities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "legality_id", null: false
    t.bigint "magic_card_id", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["legality_id"], name: "index_magic_card_legalities_on_legality_id"
    t.index ["magic_card_id", "legality_id"], name: "index_magic_card_legalities_on_magic_card_id_and_legality_id", unique: true
    t.index ["magic_card_id"], name: "index_magic_card_legalities_on_magic_card_id"
    t.index ["status"], name: "index_magic_card_legalities_on_status"
  end

  create_table "magic_card_rulings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "magic_card_id"
    t.bigint "ruling_id"
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_magic_card_rulings_on_magic_card_id"
    t.index ["ruling_id"], name: "index_magic_card_rulings_on_ruling_id"
  end

  create_table "magic_card_sub_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "magic_card_id", null: false
    t.bigint "sub_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_magic_card_sub_types_on_magic_card_id"
    t.index ["sub_type_id"], name: "index_magic_card_sub_types_on_sub_type_id"
  end

  create_table "magic_card_super_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "magic_card_id", null: false
    t.bigint "super_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_magic_card_super_types_on_magic_card_id"
    t.index ["super_type_id"], name: "index_magic_card_super_types_on_super_type_id"
  end

  create_table "magic_card_types", force: :cascade do |t|
    t.bigint "card_type_id", null: false
    t.datetime "created_at", null: false
    t.bigint "magic_card_id", null: false
    t.datetime "updated_at", null: false
    t.index ["card_type_id"], name: "index_magic_card_types_on_card_type_id"
    t.index ["magic_card_id"], name: "index_magic_card_types_on_magic_card_id"
  end

  create_table "magic_cards", force: :cascade do |t|
    t.string "art_crop"
    t.string "border_color"
    t.bigint "boxset_id"
    t.string "card_number"
    t.string "card_side"
    t.string "card_type"
    t.string "card_uuid"
    t.decimal "converted_mana_cost", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.integer "edhrec_rank"
    t.decimal "edhrec_saltiness"
    t.string "face_name"
    t.string "flavor_text"
    t.decimal "foil_price", precision: 12, scale: 2, default: "0.0"
    t.string "frame_version"
    t.boolean "has_foil"
    t.boolean "has_non_foil"
    t.jsonb "identifiers"
    t.string "image_large"
    t.string "image_medium"
    t.string "image_small"
    t.datetime "image_updated_at"
    t.boolean "is_reprint"
    t.boolean "is_token", default: false, null: false
    t.string "mana_cost"
    t.decimal "mana_value", precision: 10, scale: 2
    t.string "name"
    t.decimal "normal_price", precision: 12, scale: 2, default: "0.0"
    t.string "original_text"
    t.string "original_type"
    t.string "other_face_uuid"
    t.string "power"
    t.decimal "price_change_weekly_foil", precision: 10, scale: 2
    t.decimal "price_change_weekly_normal", precision: 10, scale: 2
    t.jsonb "price_history"
    t.string "rarity"
    t.string "text"
    t.string "toughness"
    t.datetime "updated_at", null: false
    t.index ["boxset_id"], name: "index_magic_cards_on_boxset_id"
    t.index ["price_change_weekly_foil"], name: "index_magic_cards_on_price_change_weekly_foil"
    t.index ["price_change_weekly_normal"], name: "index_magic_cards_on_price_change_weekly_normal"
  end

  create_table "precon_deck_cards", force: :cascade do |t|
    t.string "board_type", null: false
    t.datetime "created_at", null: false
    t.boolean "is_foil", default: false
    t.bigint "magic_card_id", null: false
    t.bigint "precon_deck_id", null: false
    t.integer "quantity", default: 1
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_precon_deck_cards_on_magic_card_id"
    t.index ["precon_deck_id", "magic_card_id", "board_type"], name: "idx_precon_deck_cards_unique", unique: true
    t.index ["precon_deck_id"], name: "index_precon_deck_cards_on_precon_deck_id"
  end

  create_table "precon_decks", force: :cascade do |t|
    t.boolean "cards_ingested", default: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "deck_type"
    t.string "file_name", null: false
    t.string "name", null: false
    t.date "release_date"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_precon_decks_on_code"
    t.index ["deck_type"], name: "index_precon_decks_on_deck_type"
    t.index ["file_name"], name: "index_precon_decks_on_file_name", unique: true
  end

  create_table "printings", force: :cascade do |t|
    t.string "boxset_code"
    t.datetime "created_at", null: false
    t.bigint "magic_card_id"
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_printings_on_magic_card_id"
  end

  create_table "rulings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ruling"
    t.date "ruling_date"
    t.datetime "updated_at", null: false
  end

  create_table "sub_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "super_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.jsonb "preferences", default: {}
    t.string "prices_last_updated_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "1001", null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "collection_magic_cards", "collections"
  add_foreign_key "collection_magic_cards", "collections", column: "source_collection_id"
  add_foreign_key "collection_magic_cards", "magic_cards"
  add_foreign_key "collections", "users"
  add_foreign_key "magic_card_legalities", "legalities"
  add_foreign_key "magic_card_legalities", "magic_cards"
  add_foreign_key "precon_deck_cards", "magic_cards"
  add_foreign_key "precon_deck_cards", "precon_decks"
end
