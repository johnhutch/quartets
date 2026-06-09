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

ActiveRecord::Schema[8.1].define(version: 2026_06_09_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "attempts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "guesses"
    t.integer "mistakes_count"
    t.string "player_token"
    t.bigint "puzzle_id", null: false
    t.boolean "solved"
    t.datetime "updated_at", null: false
    t.index ["player_token"], name: "index_attempts_on_player_token"
    t.index ["puzzle_id"], name: "index_attempts_on_puzzle_id"
  end

  create_table "groups", force: :cascade do |t|
    t.integer "color"
    t.datetime "created_at", null: false
    t.string "description"
    t.integer "position"
    t.bigint "puzzle_id", null: false
    t.datetime "updated_at", null: false
    t.jsonb "words"
    t.index ["puzzle_id"], name: "index_groups_on_puzzle_id"
  end

  create_table "puzzles", force: :cascade do |t|
    t.string "author_name"
    t.datetime "created_at", null: false
    t.boolean "featured", default: false, null: false
    t.string "share_token"
    t.integer "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["share_token"], name: "index_puzzles_on_share_token", unique: true
    t.index ["user_id"], name: "index_puzzles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "attempts", "puzzles"
  add_foreign_key "groups", "puzzles"
end
