require 'mutect'

describe MuTect do
  describe "#columns" do
    context "loaded from file" do
      it "parses correctly" do
        h = MuTect.new
        h.parse "fixtures/mutect.txt"

        expect(h.columns).to eq [ :contig, :position, :context, :ref_allele, :alt_allele, :tumor_name, :normal_name, :score, :dbsnp_site, :covered, :power, :tumor_power, :normal_power, :total_pairs, :improper_pairs, :map_q0_reads, :t_lod_fstar, :tumor_f, :contaminant_fraction, :contaminant_lod, :t_ref_count, :t_alt_count, :t_ref_sum, :t_alt_sum, :t_ref_max_mapq, :t_alt_max_mapq, :t_ins_count, :t_del_count, :normal_best_gt, :init_n_lod, :n_ref_count, :n_alt_count, :n_ref_sum, :n_alt_sum, :judgement ]
      end
    end
  end
end
