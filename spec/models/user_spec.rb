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

  describe "roles" do
    it "is neither superuser nor moderator by default" do
      user = create(:user)
      expect(user).not_to be_superuser
      expect(user).not_to be_moderator
      expect(user).not_to be_staff
    end

    it "counts a superuser as staff" do
      expect(create(:user, :superuser)).to be_staff
    end

    it "counts a moderator as staff" do
      expect(create(:user, :moderator)).to be_staff
    end

    describe "#role / #role=" do
      it "reads the current tier" do
        expect(create(:user).role).to eq(:member)
        expect(create(:user, :moderator).role).to eq(:moderator)
        expect(create(:user, :superuser).role).to eq(:superuser)
      end

      it "sets the underlying booleans from a role name" do
        user = create(:user)

        user.update!(role: "moderator")
        expect(user).to be_moderator
        expect(user).not_to be_superuser

        user.update!(role: "superuser")
        expect(user).to be_superuser
        expect(user).not_to be_moderator # superuser already implies staff

        user.update!(role: "member")
        expect(user).not_to be_staff
      end
    end
  end

  # Display name is optional, but once set it can be changed — never cleared.
  # Blanking it would silently un-byline every puzzle the account owns
  # (Puzzle#author_display_name falls back to per-puzzle names, usually absent
  # for accounts that had a display name).
  describe "display_name" do
    it "stays optional — a nameless legacy user can still update their account" do
      user = create(:user, display_name: nil)
      expect(user.update(email: "new@example.com")).to be(true)
    end

    it "can be set later, and changed once set" do
      user = create(:user, display_name: nil)
      expect(user.update(display_name: "Hutch")).to be(true)
      expect(user.update(display_name: "The Real Hutch")).to be(true)
    end

    it "cannot be cleared once set" do
      user = create(:user, display_name: "Hutch")
      expect(user.update(display_name: "")).to be(false)
      expect(user.errors[:display_name]).to be_present
    end
  end
end
