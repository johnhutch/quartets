# Idempotent seeds — safe to run any time, in any environment.

# --- The single superuser --------------------------------------------------
# Creds come from the environment (dotenv loads .env locally; Render/Synology set
# real values). In development only, fall back to a default so seeding — and the
# demo puzzles below — never block you for lack of env vars. Production stays
# strict: no env, no fallback.
admin_email    = ENV["ADMIN_EMAIL"]
admin_password = ENV["ADMIN_PASSWORD"]

if admin_email.blank? && Rails.env.development?
  admin_email    = "admin@example.com"
  admin_password = admin_password.presence || "password123"
  puts "No ADMIN_EMAIL set — using the development default (#{admin_email})."
end

owner =
  if admin_email.present?
    User.find_or_create_by!(email: admin_email) do |user|
      user.password = admin_password.presence || ENV.fetch("ADMIN_PASSWORD")
    end
  end

if owner
  puts "Superuser ready: #{owner.email}"
else
  puts "Skipping superuser + demo puzzles — set ADMIN_EMAIL and ADMIN_PASSWORD."
end

# --- Demo puzzles ----------------------------------------------------------
# Ten published Connections puzzles so the public site has something to play the
# moment it's up. The first five are featured — the homepage rotates among those.
# Authored here rather than imported; the real Obsidian archive is a Phase 5 job.
DEMO_PUZZLES = [
  { title: "Around the House", featured: true, groups: [
    { color: :blue,   description: "Kitchen tools",  words: %w[Whisk Ladle Grater Peeler] },
    { color: :green,  description: "Herbs",          words: %w[Basil Thyme Sage Mint] },
    { color: :yellow, description: "Trees",          words: %w[Oak Maple Birch Pine] },
    { color: :purple, description: "___ board",      words: %w[Cutting Key Surf Card] }
  ] },
  { title: "Game Night", featured: true, groups: [
    { color: :blue,   description: "Card games",     words: %w[Poker Bridge Rummy Hearts] },
    { color: :green,  description: "Chess pieces",   words: %w[King Queen Knight Bishop] },
    { color: :yellow, description: "Dice games",     words: %w[Yahtzee Craps Farkle Bunco] },
    { color: :purple, description: "On a Monopoly board", words: %w[Boardwalk Jail Thimble Hotel] }
  ] },
  { title: "Weather Report", featured: true, groups: [
    { color: :blue,   description: "Precipitation",  words: %w[Rain Snow Sleet Hail] },
    { color: :green,  description: "Clouds",         words: %w[Cirrus Cumulus Stratus Nimbus] },
    { color: :yellow, description: "Wind",           words: %w[Gale Breeze Gust Squall] },
    { color: :purple, description: "Sun ___",        words: %w[Flower Rise Set Burn] }
  ] },
  { title: "On the Map", featured: true, groups: [
    { color: :blue,   description: "Oceans",         words: %w[Pacific Atlantic Indian Arctic] },
    { color: :green,  description: "Continents",     words: %w[Africa Asia Europe Australia] },
    { color: :yellow, description: "Capital cities", words: %w[Paris Cairo Lima Oslo] },
    { color: :purple, description: "Rivers",         words: %w[Nile Amazon Danube Volga] }
  ] },
  { title: "Music to My Ears", featured: true, groups: [
    { color: :blue,   description: "String instruments", words: %w[Violin Cello Harp Banjo] },
    { color: :green,  description: "Brass",          words: %w[Trumpet Tuba Trombone Cornet] },
    { color: :yellow, description: "Tempo markings", words: %w[Largo Allegro Presto Adagio] },
    { color: :purple, description: "___ note",       words: %w[Quarter Whole Grace Bank] }
  ] },
  { title: "Sports Center", featured: false, groups: [
    { color: :blue,   description: "Tennis terms",   words: %w[Ace Deuce Lob Volley] },
    { color: :green,  description: "Boxing",         words: %w[Jab Hook Cross Uppercut] },
    { color: :yellow, description: "Golf scores",    words: %w[Birdie Eagle Bogey Par] },
    { color: :purple, description: "Baseball",       words: %w[Bunt Slider Steal Pitch] }
  ] },
  { title: "Color Wheel", featured: false, groups: [
    { color: :blue,   description: "Shades of red",    words: %w[Crimson Scarlet Ruby Cherry] },
    { color: :green,  description: "Shades of blue",   words: %w[Navy Azure Cobalt Teal] },
    { color: :yellow, description: "Shades of green",  words: %w[Olive Lime Forest Jade] },
    { color: :purple, description: "Shades of purple", words: %w[Violet Lilac Plum Mauve] }
  ] },
  { title: "Tech Talk", featured: false, groups: [
    { color: :blue,   description: "Programming languages", words: %w[Python Ruby Java Swift] },
    { color: :green,  description: "Web concepts",   words: %w[Cookie Cache Server Domain] },
    { color: :yellow, description: "Apple products",  words: %w[iPhone iPad Watch Mac] },
    { color: :purple, description: "Keyboard keys",  words: %w[Shift Enter Tab Escape] }
  ] },
  { title: "Breakfast Club", featured: false, groups: [
    { color: :blue,   description: "Egg styles",     words: %w[Poached Scrambled Fried Boiled] },
    { color: :green,  description: "Cereal",         words: %w[Cheerios Granola Muesli Bran] },
    { color: :yellow, description: "Hot drinks",     words: %w[Coffee Tea Cocoa Cider] },
    { color: :purple, description: "___ cake",       words: %w[Pan Cup Pound Crab] }
  ] },
  { title: "Movie Night", featured: false, groups: [
    { color: :blue,   description: "Film genres",    words: %w[Comedy Horror Drama Western] },
    { color: :green,  description: "Oscar categories", words: %w[Picture Director Actor Score] },
    { color: :yellow, description: "Star Wars",      words: %w[Jedi Sith Force Saber] },
    { color: :purple, description: "___ star",       words: %w[Super Rock Pop North] }
  ] }
]

if owner
  DEMO_PUZZLES.each do |data|
    Puzzle.find_or_create_by!(title: data[:title], user: owner) do |puzzle|
      puzzle.author_name = "Link the Things"
      puzzle.featured    = data[:featured]
      puzzle.status      = :published
      data[:groups].each_with_index do |group, i|
        puzzle.groups.build(
          color: group[:color],
          description: group[:description],
          words: group[:words],
          position: i
        )
      end
    end
  end

  puts "Demo puzzles: #{Puzzle.count} total, #{Puzzle.featured.count} featured."
end
