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

ActiveRecord::Schema[8.0].define(version: 2025_02_01_211727) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
  end

  create_table "card_prices", force: :cascade do |t|
    t.bigint "magic_card_id"
    t.string "mtg_uuid"
    t.jsonb "price_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["magic_card_id"], name: "index_card_prices_on_magic_card_id"
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
    t.index ["collection_id"], name: "index_collection_magic_cards_on_collection_id"
    t.index ["magic_card_id"], name: "index_collection_magic_cards_on_magic_card_id"
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
    t.index ["user_id"], name: "index_collections_on_user_id"
  end

  create_table "colors", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "keywords", force: :cascade do |t|
    t.string "keyword"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "magic_card_keywords", force: :cascade do |t|
    t.bigint "magic_card_id"
    t.bigint "keyword_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["keyword_id"], name: "index_magic_card_keywords_on_keyword_id"
    t.index ["magic_card_id"], name: "index_magic_card_keywords_on_magic_card_id"
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
    t.boolean "has_foil"
    t.boolean "has_non_foil"
    t.string "border_color"
    t.decimal "converted_mana_cost", precision: 10, scale: 2
    t.string "flavor_text"
    t.string "frame_version"
    t.boolean "is_reprint"
    t.string "card_number"
    t.jsonb "identifiers"
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
    t.index ["boxset_id"], name: "index_magic_cards_on_boxset_id"
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
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "collection_magic_cards", "collections"
  add_foreign_key "collection_magic_cards", "magic_cards"
  add_foreign_key "collections", "users"
end
