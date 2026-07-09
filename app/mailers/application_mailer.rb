class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_SENDER", "no-reply@quartets.local")
  layout "mailer"
end
