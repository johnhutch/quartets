namespace :puzzles do
  desc "Import the Obsidian Connections archive (idempotent). FILE=path overrides the default."
  task import_obsidian: :environment do
    default_path = File.expand_path(
      "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal/Connections Puzzles.md"
    )
    path  = ENV["FILE"].presence || default_path
    owner = ENV["ADMIN_EMAIL"].present? ? User.find_by(email: ENV["ADMIN_EMAIL"]) : User.first

    abort "No owner user found — seed an admin or pass ADMIN_EMAIL." if owner.nil?
    abort "Archive not found: #{path}" unless File.exist?(path)

    summary = ObsidianArchive.import(File.read(path), user: owner)

    puts "Imported as #{owner.email}:"
    puts "  published: #{summary[:published].size}  unlisted: #{summary[:unlisted].size}  skipped: #{summary[:skipped].size}"
    summary[:unlisted].each { |title| puts "  • unlisted (incomplete): #{title}" }
    summary[:skipped].each { |title| puts "  • skipped (no groups or already imported): #{title}" }
  end
end
