class InitSolidTrio < ActiveRecord::Migration[8.0]
  def up
    # When regular db:migrate runs, force it to load the trio schemas
    ['db/queue_schema.rb', 'db/cache_schema.rb', 'db/cable_schema.rb'].each do |schema|
      load Rails.root.join(schema) if File.exist?(Rails.root.join(schema))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
