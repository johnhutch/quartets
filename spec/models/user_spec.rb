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

  # The /u/:handle slug (deferred D3, ADR-0005): minted from the email's local
  # part at signup, deduped, and stable thereafter.
  describe "handle" do
    it "mints one from the email's local part" do
      expect(create(:user, email: "hutch@example.com").handle).to eq("hutch")
    end

    it "parameterizes awkward local parts" do
      expect(create(:user, email: "First.Last+tag@example.com").handle).to eq("first-last-tag")
    end

    it "dedupes collisions with a numeric suffix" do
      create(:user, email: "hutch@example.com")
      expect(create(:user, email: "hutch@other.com").handle).to eq("hutch-2")
    end

    it "never changes once minted, even if the email does" do
      user = create(:user, email: "hutch@example.com")
      user.update!(email: "new@example.com")
      expect(user.reload.handle).to eq("hutch")
    end

    it "rejects a duplicate handle" do
      create(:user, email: "hutch@example.com")
      dupe = build(:user, email: "x@example.com", handle: "hutch")
      expect(dupe).not_to be_valid
    end
  end

  it "is not a superuser by default" do
    expect(create(:user)).not_to be_superuser
  end
end
