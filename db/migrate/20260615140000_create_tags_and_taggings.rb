class CreateTagsAndTaggings < ActiveRecord::Migration[8.1]
  def change
    # Canonical tag rows (normalized, hyphenated slugs like "star-wars"). Storing
    # them as real rows — not a jsonb array — is what lets an admin later
    # merge/rename/delete to clean up cold-start spelling divergence.
    create_table :tags do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :tags, :name, unique: true

    # Polymorphic: a tagging attaches a tag to any `taggable` (puzzles today,
    # plausibly other things later). The composite unique index also covers the
    # taggable lookup, so no separate taggable index needed.
    create_table :taggings do |t|
      t.references :taggable, polymorphic: true, null: false, index: false
      t.references :tag, null: false, foreign_key: true
      t.timestamps
    end
    add_index :taggings, [:taggable_type, :taggable_id, :tag_id], unique: true,
              name: "index_taggings_on_taggable_and_tag"
  end
end
