require 'gtf'

describe GTF do
  describe "#columns" do
    context "loaded from file" do
      it "parses correctly" do
        m = GTF.new
        m.parse fixture(:gtf)

        expect(m.count).to eq(15)
      end
    end
  end
end
