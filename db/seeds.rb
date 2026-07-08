# Idempotent seeds — safe to run any time, in any environment.
#
# Two layers:
#   1. Superuser + demo puzzles — every environment (prod included).
#   2. Community fixtures — DEVELOPMENT ONLY. A cast of owners (named account,
#      handle-less account, anonymous creator, pure player), puzzles in every
#      state (published / unlisted / incomplete / themed+tagged / described /
#      anonymous / long-word stress test), and plays with real guess logs so
#      ratings, trophies, stats, common-wrong-guesses, and funnel events all
#      have data to render. This is what makes local look like prod.

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
  owner.update!(superuser: true) unless owner.superuser? # /admin needs it
  puts "Superuser ready: #{owner.email}"
else
  puts "Skipping superuser + demo puzzles — set ADMIN_EMAIL and ADMIN_PASSWORD."
end

# --- Demo puzzles ----------------------------------------------------------
# Ten published Connections puzzles so the public site has something to play the
# moment it's up. The first five are featured — the homepage rotates among those.
DEMO_PUZZLES = [
  { title: "Around the House", featured: true,
    description: "Domestic bliss, sixteen words at a time. Watch the purple row.",
    groups: [
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
  { title: "Movie Night", featured: false,
    description: "Lights down, phones off. One group is a trap for film bros.",
    groups: [
      { color: :blue,   description: "Film genres",    words: %w[Comedy Horror Drama Western] },
      { color: :green,  description: "Oscar categories", words: %w[Picture Director Actor Score] },
      { color: :yellow, description: "Star Wars",      words: %w[Jedi Sith Force Saber] },
      { color: :purple, description: "___ star",       words: %w[Super Rock Pop North] }
    ] }
]

# Builds/refreshes one seed-managed puzzle. Attributes re-assert on every run
# (the set is seed-managed, not hand-edited); groups only build once.
def seed_puzzle(data, user: nil, creator_token: nil)
  puzzle = Puzzle.find_or_initialize_by(title: data[:title], user: user, creator_token: creator_token)

  puzzle.author_name = data[:author_name]
  puzzle.featured    = data.fetch(:featured, false)
  puzzle.status      = data.fetch(:status, :published)
  puzzle.specialized = data.fetch(:specialized, false)
  puzzle.description = data[:description]

  if puzzle.new_record?
    Array(data[:groups]).each_with_index do |group, i|
      puzzle.groups.build(
        color: group[:color],
        description: group[:description],
        words: group[:words],
        position: i
      )
    end
  end

  puzzle.save!
  puzzle.tag_names = data[:tags] if data[:tags] # replaces; idempotent
  puzzle
end

if owner
  DEMO_PUZZLES.each { |data| seed_puzzle(data.merge(author_name: "Demo"), user: owner) }
  puts "Demo puzzles: #{Puzzle.where(author_name: "Demo").count} (#{Puzzle.featured.count} featured)."
end

# ============================================================================
# Community fixtures — development only from here down.
# ============================================================================
return unless Rails.env.development?

# --- The cast ---------------------------------------------------------------
# All dev accounts share the password below. Handles mint from the email
# local-part (wordsmith / casual / player).
DEV_PASSWORD = "password123"

def seed_user(email, display_name: nil)
  user = User.find_or_create_by!(email: email) { |u| u.password = DEV_PASSWORD }
  user.update!(display_name: display_name) if display_name && user.display_name != display_name
  user
end

wordsmith = seed_user("wordsmith@example.com", display_name: "The Wordsmith") # prolific author, themed + classic
casual    = seed_user("casual@example.com")                                   # no display_name — bylines fall to author_name
player    = seed_user("player@example.com", display_name: "Speedrun Sally")   # pure player: no puzzles, all trophies

ANON_CREATOR = "seed-anon-creator" # a logged-out author's cookie token

# --- Community puzzles — every state the app knows --------------------------

# Published + themed + tagged + described (the discovery-authoring surface).
galaxy = seed_puzzle({
  title: "Galaxy Brain", specialized: true, tags: ["star wars", "movies"],
  description: "Every group is a corner of the Star Wars galaxy. Nerf-herders welcome.",
  groups: [
    { color: :yellow, description: "Droids",         words: %w[R2-D2 C-3PO BB-8 K-2SO] },
    { color: :green,  description: "Planets",        words: %w[Tatooine Hoth Endor Naboo] },
    { color: :blue,   description: "Bounty hunters", words: %w[Boba Jango Greedo Dengar] },
    { color: :purple, description: "Ships",          words: %w[Falcon X-wing Slave Executor] }
  ]
}, user: wordsmith)

court = seed_puzzle({
  title: "Court Vision", specialized: true, tags: ["nba", "sports"],
  description: "Hoops history, deep cuts only. Casuals will get cooked.",
  groups: [
    { color: :yellow, description: "NBA teams",      words: %w[Heat Jazz Nets Suns] },
    { color: :green,  description: "Point guards",   words: %w[Curry Magic Stockton Kidd] },
    { color: :blue,   description: "Dunk types",     words: %w[Windmill Tomahawk Alley-oop Reverse] },
    { color: :purple, description: "Bygone arenas",  words: %w[Garden Forum Palace Spectrum] }
  ]
}, user: wordsmith)

# Published classic with a description, from the handle-less account (byline
# comes from the puzzle's own author_name).
deep_end = seed_puzzle({
  title: "Deep End", author_name: "poolboy",
  description: "Everything's wet. That's it, that's the theme.",
  groups: [
    { color: :yellow, description: "Swim strokes",    words: %w[Freestyle Butterfly Backstroke Breaststroke] },
    { color: :green,  description: "Bodies of water", words: %w[Lagoon Fjord Bayou Strait] },
    { color: :blue,   description: "Pool gear",       words: %w[Goggles Noodle Flippers Snorkel] },
    { color: :purple, description: "___ dive",        words: %w[Swan Nose Crash Dumpster] }
  ]
}, user: casual)

# Long-word stress test — exercises the per-tile font-fit and hyphenation.
sesqui = seed_puzzle({
  title: "Sesquipedalian", author_name: "poolboy",
  groups: [
    { color: :yellow, description: "Tiny, verbosely",   words: %w[Infinitesimal Microscopic Minuscule Lilliputian] },
    { color: :green,  description: "Huge, verbosely",   words: %w[Gargantuan Brobdingnagian Colossal Elephantine] },
    { color: :blue,   description: "Say that again?",   words: %w[Otorhinolaryngology Antidisestablishmentarianism Floccinaucinihilipilification Pneumonoultramicroscopic] },
    { color: :purple, description: "Fancy talk",        words: %w[Sesquipedalian Grandiloquent Magniloquent Perspicacious] }
  ]
}, user: casual)

# Anonymous author: published, cookie-owned, no account anywhere.
ghost = seed_puzzle({
  title: "Ghost Writer Special", author_name: "a friendly ghost",
  groups: [
    { color: :yellow, description: "Ghost words",    words: %w[Boo Wraith Phantom Specter] },
    { color: :green,  description: "Haunted places", words: %w[Manor Crypt Attic Cellar] },
    { color: :blue,   description: "Famous spooks",  words: %w[Casper Slimer Beetlejuice Bogeyman] },
    { color: :purple, description: "___ town",       words: %w[Ghost Down Home Funky] }
  ]
}, creator_token: ANON_CREATOR)

# Unlisted-but-complete: playable by anyone with the link, off the site (ADR-0008).
seed_puzzle({
  title: "Secret Menu", status: :unlisted,
  description: "Link-only. If you're here, someone trusted you.",
  groups: [
    { color: :yellow, description: "Burger toppings",  words: %w[Lettuce Pickle Onion Mayo] },
    { color: :green,  description: "Fast-food chains", words: %w[Wendys Arbys Sonic Whataburger] },
    { color: :blue,   description: "Sauces",           words: %w[Ranch Aioli Sriracha Chipotle] },
    { color: :purple, description: "Animal ___",       words: %w[Style Fries Crackers House] }
  ]
}, user: wordsmith)

# Incomplete drafts: one account-owned mid-authoring, one anonymous scrap.
seed_puzzle({
  title: "Half-Baked Idea", status: :unlisted,
  groups: [
    { color: :yellow, description: "Bread",  words: %w[Rye Sourdough Brioche Pumpernickel] },
    { color: :green,  description: "",       words: ["Croissant", "", "", ""] }
  ]
}, user: wordsmith)

seed_puzzle({ title: "Scraps", status: :unlisted, groups: [] }, creator_token: ANON_CREATOR)

puts "Community puzzles: #{Puzzle.count} total " \
     "(#{Puzzle.published.count} published, #{Puzzle.where(specialized: true).count} themed, " \
     "#{Puzzle.where(user_id: nil).where.not(creator_token: nil).count} anonymous)."

# --- Plays: guess logs, trophies, ratings, timings ---------------------------
# Achievements are DERIVED from the guess log in Attempt#before_create, so each
# play is built from the puzzle's real words in a real solve order.

def right(puzzle, color, t:)
  { "words" => puzzle.groups.detect { |g| g.color == color.to_s }.words,
    "colors" => [color.to_s] * 4, "t" => t }
end

# A near-miss: three from `main`, one from `odd` — the classic wrong guess.
def wrong(puzzle, main, odd, t:)
  main_words = puzzle.groups.detect { |g| g.color == main.to_s }.words
  odd_word   = puzzle.groups.detect { |g| g.color == odd.to_s }.words.first
  { "words" => main_words.first(3) + [odd_word],
    "colors" => [main.to_s] * 3 + [odd.to_s], "t" => t }
end

# One play, once: anonymous plays key on (puzzle, player_token); account plays
# on (puzzle, user) — same identities the app itself uses.
def seed_play(puzzle, token:, user: nil, guesses:, solved:, quality: nil, difficulty: nil)
  existing = user ? puzzle.attempts.where(user: user) : puzzle.attempts.where(player_token: token, user: nil)
  return if existing.exists?

  puzzle.attempts.create!(
    player_token: token, user: user, guesses: guesses, solved: solved,
    mistakes_count: guesses.count { |g| g["colors"].uniq.size > 1 },
    duration_ms: guesses.last&.fetch("t"),
    quality: quality, difficulty: difficulty
  )
end

around = Puzzle.find_by!(title: "Around the House")
game_night = Puzzle.find_by!(title: "Game Night")
weather = Puzzle.find_by!(title: "Weather Report")

# "Around the House": a crowd. Two players make the SAME wrong guess (feeds the
# common-wrong-guesses stat), one flawless, one flawed win, one loss. Ratings
# lean friendly.
seed_play(around, token: "seed-p1", solved: true, quality: :yeah, difficulty: :pretty_easy,
  guesses: [right(around, :yellow, t: 21_000), right(around, :green, t: 48_000),
            right(around, :blue, t: 70_000), right(around, :purple, t: 84_000)])
seed_play(around, token: "seed-p2", solved: true, quality: :hell_yeah, difficulty: :not_bad,
  guesses: [wrong(around, :green, :yellow, t: 30_000), right(around, :green, t: 55_000),
            right(around, :yellow, t: 76_000), right(around, :blue, t: 101_000),
            right(around, :purple, t: 118_000)])
seed_play(around, token: "seed-p3", solved: true, quality: :yeah, difficulty: :not_bad,
  guesses: [wrong(around, :green, :yellow, t: 41_000), # same miss as seed-p2
            right(around, :blue, t: 88_000), right(around, :green, t: 120_000),
            right(around, :yellow, t: 141_000), right(around, :purple, t: 150_000)])
seed_play(around, token: "seed-p4", solved: false, difficulty: :pretty_hard,
  guesses: [wrong(around, :blue, :purple, t: 33_000), wrong(around, :green, :yellow, t: 61_000),
            wrong(around, :blue, :green, t: 95_000), wrong(around, :purple, :blue, t: 132_000)])
seed_play(around, token: "seed-p5", solved: true, # played, never rated
  guesses: [right(around, :green, t: 25_000), right(around, :yellow, t: 44_000),
            right(around, :blue, t: 67_000), right(around, :purple, t: 80_000)])

# "Galaxy Brain": themed and beloved-but-brutal — hell-yeahs AND cursed votes.
seed_play(galaxy, token: "seed-#{player.handle}", user: player, solved: true,
  quality: :hell_yeah, difficulty: :cursed,
  guesses: [right(galaxy, :purple, t: 95_000), right(galaxy, :blue, t: 160_000),
            right(galaxy, :green, t: 190_000), right(galaxy, :yellow, t: 201_000)]) # reverse rainbow
seed_play(galaxy, token: "seed-p6", solved: true, quality: :hell_yeah, difficulty: :pretty_hard,
  guesses: [wrong(galaxy, :blue, :purple, t: 62_000), right(galaxy, :yellow, t: 98_000),
            right(galaxy, :green, t: 133_000), right(galaxy, :blue, t: 170_000),
            right(galaxy, :purple, t: 181_000)])
seed_play(galaxy, token: "seed-p7", solved: false, difficulty: :cursed,
  guesses: [wrong(galaxy, :green, :yellow, t: 45_000), wrong(galaxy, :blue, :purple, t: 90_000),
            wrong(galaxy, :purple, :blue, t: 140_000), wrong(galaxy, :blue, :green, t: 185_000)])

# "Court Vision": mostly carnage. Cursed, deservedly.
seed_play(court, token: "seed-#{player.handle}", user: player, solved: false, difficulty: :cursed,
  guesses: [wrong(court, :yellow, :green, t: 50_000), wrong(court, :purple, :yellow, t: 105_000),
            wrong(court, :green, :blue, t: 160_000), wrong(court, :yellow, :purple, t: 210_000)])
seed_play(court, token: "seed-p8", solved: true, quality: :yeah, difficulty: :cursed,
  guesses: [wrong(court, :purple, :yellow, t: 70_000), wrong(court, :green, :yellow, t: 130_000),
            right(court, :blue, t: 180_000), right(court, :green, t: 230_000),
            right(court, :yellow, t: 260_000), right(court, :purple, t: 271_000)])

# "Deep End": the friendly one. Fast solves, easy votes.
seed_play(deep_end, token: "seed-p1", solved: true, quality: :yeah, difficulty: :pretty_easy,
  guesses: [right(deep_end, :yellow, t: 15_000), right(deep_end, :blue, t: 31_000),
            right(deep_end, :green, t: 47_000), right(deep_end, :purple, t: 58_000)])
seed_play(deep_end, token: "seed-p2", solved: true, quality: :yeah, difficulty: :pretty_easy,
  guesses: [right(deep_end, :green, t: 19_000), right(deep_end, :yellow, t: 36_000),
            right(deep_end, :blue, t: 52_000), right(deep_end, :purple, t: 63_000)])

# "Sesquipedalian": one win, one loss, split verdict.
seed_play(sesqui, token: "seed-p3", solved: true, quality: :hell_yeah, difficulty: :cursed,
  guesses: [right(sesqui, :blue, t: 80_000), right(sesqui, :yellow, t: 150_000),
            right(sesqui, :green, t: 210_000), right(sesqui, :purple, t: 240_000)])
seed_play(sesqui, token: "seed-p4", solved: false, difficulty: :cursed,
  guesses: [wrong(sesqui, :purple, :green, t: 90_000), wrong(sesqui, :yellow, :purple, t: 150_000),
            wrong(sesqui, :green, :yellow, t: 200_000), wrong(sesqui, :purple, :yellow, t: 240_000)])

# "Ghost Writer Special": modest traffic for the anonymous author's stats.
seed_play(ghost, token: "seed-p5", solved: true, quality: :yeah, difficulty: :not_bad,
  guesses: [right(ghost, :yellow, t: 28_000), right(ghost, :green, t: 60_000),
            right(ghost, :blue, t: 92_000), right(ghost, :purple, t: 110_000)])

# Speedrun Sally's trophy case: reverse rainbow (Galaxy Brain, above) +
# purple-first + plain perfect + that Court Vision loss.
seed_play(weather, token: "seed-#{player.handle}", user: player, solved: true,
  quality: :yeah, difficulty: :not_bad,
  guesses: [right(weather, :purple, t: 40_000), right(weather, :green, t: 75_000),
            right(weather, :blue, t: 104_000), right(weather, :yellow, t: 118_000)]) # purple first
seed_play(game_night, token: "seed-#{player.handle}", user: player, solved: true,
  quality: :hell_yeah, difficulty: :not_bad,
  guesses: [right(game_night, :yellow, t: 22_000), right(game_night, :green, t: 51_000),
            right(game_night, :blue, t: 79_000), right(game_night, :purple, t: 96_000)]) # perfect

puts "Plays: #{Attempt.count} attempts " \
     "(#{Attempt.where(solved: true).count} solved, " \
     "#{Attempt.where.not(achievement: nil).count} with trophies, " \
     "#{Attempt.where.not(quality: nil).or(Attempt.where.not(difficulty: nil)).count} rated)."

# --- Funnel events (analytics stream B raw material) ------------------------
# game_started beacons: every finisher fired one, plus two tokens that started
# and never finished — the derived-abandon case.
def seed_start(puzzle, token)
  Event.find_or_create_by!(puzzle: puzzle, player_token: token, event_type: :game_started)
end

around.attempts.find_each { |a| seed_start(around, a.player_token) }
seed_start(around, "seed-abandon-1")
seed_start(around, "seed-abandon-2")
galaxy.attempts.find_each { |a| seed_start(galaxy, a.player_token) }

puts "Events: #{Event.count} game_started (#{2} seeded abandons on '#{around.title}')."

# --- Cheat sheet -------------------------------------------------------------
puts <<~NOTE

  Dev logins (@example.com accounts share "#{DEV_PASSWORD}"; the superuser uses ADMIN_PASSWORD):
    #{admin_email} — superuser (/admin), owns the Demo set
    wordsmith@example.com — themed + classic + unlisted + a draft (display name "The Wordsmith")
    casual@example.com — no display_name; bylines say "poolboy"
    player@example.com — no puzzles, full trophy case ("Speedrun Sally")
  Anonymous creator: cookie token "#{ANON_CREATOR}" owns "Ghost Writer Special" + the "Scraps" draft
  (to browse as them: sign a cookie in the console or just eyeball /play where their work is public).
NOTE
