# Multicolor splits titles into 3–6-letter <span> runs, so a contiguous title
# never appears in the raw HTML. Request specs asserting visible copy should
# check the rendered TEXT (what a reader sees), not the markup — this is the
# request-spec cousin of Capybara's text matching.
module PageText
  def page_text
    Nokogiri::HTML(response.body).text
  end
end

RSpec.configure do |config|
  config.include PageText, type: :request
end
