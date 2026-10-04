# Bearer tokens for the Godot game client, which can't sensibly carry a cookie session plus CSRF.
# Only the SHA-256 of a token is stored; the raw value is shown to the client once, at login
class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :name, null: false
      t.datetime :last_used_at
      t.datetime :expires_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :api_tokens, :token_digest, unique: true
  end
end
