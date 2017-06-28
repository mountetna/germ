require 'vcf'

describe VCF do
  describe "#columns" do
    context "loaded from file" do
      it "parses correctly" do
        v = VCF.new
        v.parse fixture(:vcf)

        expect(v.columns).to eq [ :chrom, :pos, :id, :ref, :alt, :qual, :filter, :info, :format, :l17_blood, :l19_treated ]
      end
    end
  end
  describe "#samples" do
    it "returns the list of samples" do
      v = VCF.new
      v.parse fixture(:vcf)

      expect(v.samples).to eq [ :l17_blood, :l19_treated ]
    end
  end
end

describe VCF::Genotype do
  describe ".<format>" do
    it "responds to any formatted column" do
      v = VCF.new
      v.parse fixture(:vcf)
      row = v.first
      geno = row.genotype(v.samples.first)
      expect(row.format.all? do |f|
        geno.respond_to? f.downcase.to_sym
      end).to be(true)
    end
  end

  describe "#to_s" do
    it "prints the formatted string for this genotype" do
      v = VCF.new
      v.parse fixture(:vcf)

      expect(v.first.genotype(:l17_blood).to_s).to eq("0/1:22,210:232:0.22727273,0.2809524:58.045456,58.061905:26.969135,28.54125:0.0,0.0014306152:40,18:59,19:7,15,69,141")
    end
  end
end
