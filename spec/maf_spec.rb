require 'maf'

describe Maf do
  describe "#columns" do
    context "loaded from file" do
      it "parses correctly" do
        m = Maf.new
        m.parse "fixtures/maf.txt"

        expect(m.columns).to eq [ :hugo_symbol, :entrez_gene_id, :center, :ncbi_build, :chromosome, :start_position, :end_position, :strand, :variant_classification, :variant_type, :reference_allele, :tumor_seq_allele1, :tumor_seq_allele2, :dbsnp_rs, :dbsnp_val_status, :tumor_sample_barcode, :matched_norm_sample_barcode, :match_norm_seq_allele1, :match_norm_seq_allele2, :tumor_validation_allele1, :tumor_validation_allele2, :match_norm_validation_allele1, :match_norm_validation_allele2, :verification_status, :validation_status, :mutation_status, :sequencing_phase, :sequence_source, :validation_method, :score, :bam_file, :sequencer ]
      end
    end
  end
end
