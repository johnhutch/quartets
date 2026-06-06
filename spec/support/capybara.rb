require "capybara/rspec"

# iPhone is *the* device, so JS system specs run at a phone-sized viewport by
# default. CSS px for an iPhone 14/15 class screen.
MOBILE_VIEWPORT = "390,844".freeze

# Homebrew's chromedriver on PATH can drift ahead of the installed Chrome
# (e.g. driver 149 vs Chrome 148), which makes Selenium fail to start a session.
# Prefer a Selenium-cached chromedriver whose major version matches Chrome, and
# fall back to PATH/Selenium Manager when no cached match is found.
def matching_chromedriver_service
  chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  return nil unless File.exist?(chrome)

  major = `"#{chrome}" --version`[/\d+/]
  return nil unless major

  driver = Dir.glob(File.expand_path("~/.cache/selenium/chromedriver/**/#{major}.*/chromedriver"))
              .find { |path| File.executable?(path) }
  return nil unless driver

  Selenium::WebDriver::Chrome::Service.new(path: driver)
end

Capybara.register_driver :mobile_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new(
    args: %W[--headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu --window-size=#{MOBILE_VIEWPORT}]
  )
  kwargs = { browser: :chrome, options: options }
  if (service = matching_chromedriver_service)
    kwargs[:service] = service
  end
  Capybara::Selenium::Driver.new(app, **kwargs)
end

# Auto-save debounces for a second, then a fetch round-trips — give Capybara
# room to wait on the resulting DOM/state instead of racing it.
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :mobile_chrome_headless
  end

  # Devise's integration `sign_in` doesn't survive a real browser session; Warden
  # injects the logged-in user into the rack session instead. Use `login_as`.
  config.include Warden::Test::Helpers, type: :system
  config.before(:each, type: :system) { Warden.test_mode! }
  config.after(:each, type: :system) { Warden.test_reset! }
end
