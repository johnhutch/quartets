# Idempotent seeds — safe to run any time, in any environment.

# The single superuser. Creds come from the environment, never the repo.
# Set ADMIN_EMAIL and ADMIN_PASSWORD before running `bin/rails db:seed`
# (and in Render's env for production).
admin_email = ENV["ADMIN_EMAIL"]

if admin_email.present?
  User.find_or_create_by!(email: admin_email) do |user|
    user.password = ENV.fetch("ADMIN_PASSWORD")
  end
  puts "Superuser ready: #{admin_email}"
else
  puts "Skipping superuser seed — set ADMIN_EMAIL and ADMIN_PASSWORD to create one."
end
