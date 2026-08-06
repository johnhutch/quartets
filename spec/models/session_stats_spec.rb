require "rails_helper"

RSpec.describe SessionStats do
  let(:user) { create(:user) }

  def sign_in_event(type, user:, at:)
    Event.create!(event_type: type, user: user, occurred_at: at)
  end

  describe "counts" do
    it "splits sign-ins by how the person got in" do
      sign_in_event(:signed_in, user: user, at: 2.days.ago)
      sign_in_event(:signed_in, user: user, at: 1.day.ago)
      sign_in_event(:signed_in_remembered, user: user, at: 12.hours.ago)

      stats = described_class.new(since: 30.days.ago)

      expect(stats.password_sign_ins).to eq(2)
      expect(stats.remembered_sign_ins).to eq(1)
      expect(stats.total_sign_ins).to eq(3)
    end

    it "ignores events outside the window" do
      sign_in_event(:signed_in, user: user, at: 40.days.ago)

      expect(described_class.new(since: 30.days.ago).password_sign_ins).to eq(0)
    end

    it "ignores play-funnel events entirely" do
      Event.create!(event_type: :game_started, player_token: "tok", occurred_at: 1.day.ago)

      stats = described_class.new(since: 30.days.ago)

      expect(stats.total_sign_ins).to eq(0)
    end
  end

  describe "#re_login_rate" do
    it "is the share of sign-ins that made somebody type a password" do
      3.times { |i| sign_in_event(:signed_in, user: user, at: (i + 1).days.ago) }
      sign_in_event(:signed_in_remembered, user: user, at: 5.hours.ago)

      expect(described_class.new(since: 30.days.ago).re_login_rate).to eq(0.75)
    end

    it "is zero rather than a divide-by-zero when nobody has signed in" do
      expect(described_class.new(since: 30.days.ago).re_login_rate).to eq(0.0)
    end
  end

  describe "#median_days_between_password_sign_ins" do
    it "measures the gap between an account's consecutive password sign-ins" do
      sign_in_event(:signed_in, user: user, at: 10.days.ago)
      sign_in_event(:signed_in, user: user, at: 6.days.ago) # 4-day gap

      expect(described_class.new(since: 30.days.ago)
               .median_days_between_password_sign_ins).to be_within(0.01).of(4.0)
    end

    it "takes the median across accounts" do
      other = create(:user)
      sign_in_event(:signed_in, user: user,  at: 20.days.ago)
      sign_in_event(:signed_in, user: user,  at: 18.days.ago) # 2 days
      sign_in_event(:signed_in, user: other, at: 20.days.ago)
      sign_in_event(:signed_in, user: other, at: 14.days.ago) # 6 days

      expect(described_class.new(since: 30.days.ago)
               .median_days_between_password_sign_ins).to be_within(0.01).of(4.0)
    end

    it "never pairs one account's sign-in with another's" do
      other = create(:user)
      sign_in_event(:signed_in, user: user,  at: 10.days.ago)
      sign_in_event(:signed_in, user: other, at: 9.days.ago)

      expect(described_class.new(since: 30.days.ago)
               .median_days_between_password_sign_ins).to be_nil
    end

    it "is nil — not zero — when nobody signed in with a password twice" do
      sign_in_event(:signed_in, user: user, at: 3.days.ago)
      sign_in_event(:signed_in_remembered, user: user, at: 1.day.ago)

      expect(described_class.new(since: 30.days.ago)
               .median_days_between_password_sign_ins).to be_nil
    end
  end
end
