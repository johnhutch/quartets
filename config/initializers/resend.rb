# Resend HTTP API key for outbound mail (the :resend delivery method, used in
# production — see config/environments/production.rb). Only set when configured;
# the resend gem raises if the key is missing when it tries to send. Same key you
# would have used as the SMTP password.
Resend.api_key = ENV["RESEND_API_KEY"] if ENV["RESEND_API_KEY"].present?
