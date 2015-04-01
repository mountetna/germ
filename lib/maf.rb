require 'hash_table'
require 'genomic_locus'

class Maf < HashTable
  print_columns
  required :hugo_symbol, :entrez_gene_id, :center, :ncbi_build, :chromosome,
    :start_position, :end_position, :strand, :variant_classification,
    :variant_type, :reference_allele, :tumor_seq_allele1, :tumor_seq_allele2,
    :dbsnp_rs, :dbsnp_val_status, :tumor_sample_barcode,
    :matched_norm_sample_barcode, :match_norm_seq_allele1,
    :match_norm_seq_allele2, :tumor_validation_allele1,
    :tumor_validation_allele2, :match_norm_validation_allele1,
    :match_norm_validation_allele2, :verification_status, :validation_status,
    :mutation_status, :sequencing_phase, :sequence_source, :validation_method,
    :score
  types :start_position => :int, :end_position => :int,
    # optional types
    :tumor_var_freq => :float, 
    :tumor_ref_count => :int, :t_ref_count => :int, 
    :normal_ref_count => :int, :n_ref_count => :int,
    :tumor_alt_count => :int, :t_alt_count => :int, 
    :normal_alt_count => :int, :n_alt_count => :int

  display_names :hugo_symbol => :Hugo_Symbol, :entrez_gene_id => :Entrez_Gene_Id, :center => :Center,
     :ncbi_build => :NCBI_Build, :chromosome => :Chromosome,
     :start_position => :Start_Position, :end_position => :End_Position, :strand => :Strand,
     :variant_classification => :Variant_Classification, :variant_type => :Variant_Type,
     :reference_allele => :Reference_Allele, :tumor_seq_allele1 => :Tumor_Seq_Allele1, :tumor_seq_allele2 => :Tumor_Seq_Allele2,
     :dbsnp_rs => :dbSNP_RS, :dbsnp_val_status => :dbSNP_Val_Status,
     :tumor_sample_barcode => :Tumor_Sample_Barcode, :matched_norm_sample_barcode => :Matched_Norm_Sample_Barcode,
     :match_norm_seq_allele1 => :Match_Norm_Seq_Allele1, :match_norm_seq_allele2 => :Match_Norm_Seq_Allele2,
     :tumor_validation_allele1 => :Tumor_Validation_Allele1, :tumor_validation_allele2 => :Tumor_Validation_Allele2,
     :match_norm_validation_allele1 => :Match_Norm_Validation_Allele1, :match_norm_validation_allele2 => :Match_Norm_Validation_Allele2,
     :verification_status => :Verification_Status, :validation_status => :Validation_Status,
     :mutation_status => :Mutation_Status, :sequencing_phase => :Sequencing_Phase, :sequence_source => :Sequence_Source,
     :validation_method => :Validation_Method, :score => :Score

  def preamble
    [ "#version 2.2" ]
  end

  comment "#"

  class Line < HashTable::Row
    include GenomicLocus
    alias_key :seqname, :chromosome
    alias_key :pos, :start_position
    alias_key :start, :start_position
    alias_key :stop, :end_position
    alias_key :ref, :reference_allele

    def copy; default_copy; end

    def alt
      tumor_seq_allele1 == reference_allele ? tumor_seq_allele2 : tumor_seq_allele1
    end

    def respond_to_missing? sym, include_all = false
      [ :ref_count, :alt_count ].include?(sym) || super
    end

    def method_missing sym, *args, &block
      if sym == :ref_count
        [ :t_ref_count, :tumor_ref_count ].each do |s|
          return send(s) if respond_to? s
        end
        nil
      elsif sym == :alt_count
        [ :t_alt_count, :tumor_alt_count ].each do |s|
          return send(s) if respond_to? s
        end
        nil
      else
        super
      end
    end
  end
end
