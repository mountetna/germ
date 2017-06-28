require 'seg'

describe Seg do
  describe "#columns" do
    context "loaded from file" do
      it "parses correctly" do
        m = Seg.new
        m.parse fixture(:seg)

        expect(m.columns).to eq [ :id, :chrom, :loc_start, :loc_end, :num_mark, :seg_mean ]
        expect(m.display_names.values).to eq [ :ID, :"loc.start", :"loc.end", :"num.mark", :"seg.mean" ]
      end
    end
  end
end
