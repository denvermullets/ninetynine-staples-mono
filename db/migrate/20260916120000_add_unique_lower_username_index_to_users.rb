class AddUniqueLowerUsernameIndexToUsers < ActiveRecord::Migration[8.1]
  def up
    abort_on_username_collisions!

    add_index :users, 'LOWER(username)', unique: true, name: 'index_users_on_lower_username'
  end

  def down
    remove_index :users, name: 'index_users_on_lower_username'
  end

  private

  # Every trade route keys on :username, so two rows that only differ by case
  # would send a proposal to the wrong person. Refuse to pick a winner here -
  # resolve the collisions by hand, then re-run the migration.
  def abort_on_username_collisions!
    collisions = select_rows(<<~SQL.squish)
      SELECT LOWER(username), COUNT(*), STRING_AGG(id::text, ', ' ORDER BY id)
      FROM users
      GROUP BY LOWER(username)
      HAVING COUNT(*) > 1
      ORDER BY LOWER(username)
    SQL
    return if collisions.empty?

    lines = collisions.map { |name, count, ids| "  #{name.inspect}: #{count} rows (user ids #{ids})" }
    raise ActiveRecord::MigrationError,
          "Cannot add unique username index: #{collisions.size} case-insensitive collision(s):\n#{lines.join("\n")}"
  end
end
