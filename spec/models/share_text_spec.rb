require "rails_helper"

# The full block a finished player copies to brag — title + cube + a direct link
# back, not just the bare 🟨🟩🟦🟪 grid. Pure value object; the URL is handed in
# so the host comes from the request (whatever domain we land on), never a
# hardcode.
RSpec.describe ShareText do
  def text(title: "Capital Cities", cube: "🟩🟩🟩🟩", url: "https://example.com/p/abc123")
    described_class.new(title:, cube:, url:).to_s
  end

  it "leads with the brand and the puzzle title" do
    expect(text(title: "Capital Cities").lines.first.chomp).to eq("Quartets — Capital Cities")
  end

  it "carries the cube grid verbatim" do
    cube = "🟩🟩🟩🟩\n🟦🟦🟦🟦"
    expect(text(cube:)).to include(cube)
  end

  it "includes a direct link to the puzzle" do
    expect(text(url: "https://playquartets.com/p/xyz")).to include("https://playquartets.com/p/xyz")
  end

  it "assembles in order — title, then cube, then link" do
    result = text(title: "Fruits", cube: "🟨🟨🟨🟨", url: "https://example.com/p/t")
    expect(result).to eq("Quartets — Fruits\n\n🟨🟨🟨🟨\n\nhttps://example.com/p/t")
  end
end
