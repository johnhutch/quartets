require "rails_helper"

RSpec.describe User, type: :model do
  it "has a valid factory" do
    expect(build(:user)).to be_valid
  end

  it "requires an email" do
    expect(build(:user, email: nil)).not_to be_valid
  end

  it "requires a password" do
    expect(build(:user, password: nil)).not_to be_valid
  end

  it "rejects a duplicate email" do
    existing = create(:user)
    expect(build(:user, email: existing.email)).not_to be_valid
  end

  it "stores the password encrypted, never in the clear" do
    user = create(:user, password: "correct-horse-battery-staple")
    expect(user.encrypted_password).to be_present
    expect(user.encrypted_password).not_to eq("correct-horse-battery-staple")
  end
end
