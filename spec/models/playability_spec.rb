require "rails_helper"

# The ADR-0008 play gate as a policy object: given the looked-up puzzle (nil for an
# unknown token) and whether the viewer owns it, is it playable — and if not, why?
# One definition the play page and the attempt recorder share.
RSpec.describe Playability do
  let(:complete)   { build(:published_puzzle) } # 4 filled groups
  let(:incomplete) { build(:puzzle) }           # no groups

  describe "#playable? (owner-agnostic: completeness, not visibility)" do
    it "is true for a complete puzzle, ownership irrelevant" do
      expect(described_class.new(complete)).to be_playable
      expect(described_class.new(complete, owner: true)).to be_playable
    end

    it "is false for an incomplete puzzle" do
      expect(described_class.new(incomplete)).not_to be_playable
    end

    it "is false for an unknown token (nil puzzle)" do
      expect(described_class.new(nil)).not_to be_playable
    end
  end

  describe "#status" do
    it "is :playable for a complete puzzle" do
      expect(described_class.new(complete).status).to eq(:playable)
    end

    it "is :editable for an incomplete puzzle the viewer owns" do
      expect(described_class.new(incomplete, owner: true).status).to eq(:editable)
    end

    it "is :missing for an incomplete puzzle a stranger hits" do
      expect(described_class.new(incomplete, owner: false).status).to eq(:missing)
    end

    it "is :missing for an unknown token" do
      expect(described_class.new(nil, owner: true).status).to eq(:missing)
    end
  end
end
