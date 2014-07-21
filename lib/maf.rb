#!/usr/bin/env ruby

require 'oncotator'
require 'yaml'
require 'mutation_set'

class Maf < Mutation::Collection
  requires "Hugo_Symbol", "Entrez_Gene_Id", "Center",
    "NCBI_Build", "Chromosome", 
    "Start_Position", "End_Position", "Strand", 
    "Variant_Classification", "Variant_Type", 
    "Reference_Allele", "Tumor_Seq_Allele1", "Tumor_Seq_Allele2", 
    "dbSNP_RS", "dbSNP_Val_Status", 
    "Tumor_Sample_Barcode", "Matched_Norm_Sample_Barcode", 
    "Match_Norm_Seq_Allele1", "Match_Norm_Seq_Allele2", 
    "Tumor_Validation_Allele1", "Tumor_Validation_Allele2", 
    "Match_Norm_Validation_Allele1", "Match_Norm_Validation_Allele2", 
    "verification_Status", "Validation_Status", 
    "Mutation_Status", "Sequencing_Phase", "Sequence_Source", 
    "Validation_Method", "Score" #, "BAM_File", "Sequencer"
  comments "#"

  def preamble
    "#version 2.2"
  end

  class Line < Mutation::Record
    alias_key :chrom, :chromosome
    alias_key :start, :start_position
    alias_key :stop, :end_position
    alias_key :ref_allele, :reference_allele

    def skip_maf?
      criteria_failed?(self, :maf)
    end

    def key
      [ tumor_sample_barcode, chrom, start, stop ].join(":")
    end

    def alt_allele
      tumor_seq_allele1 == reference_allele ? tumor_seq_allele2 : tumor_seq_allele1
    end

    def _ref_count
      [ :t_ref_count, :tumor_ref_count, :ref_count ].each do |s|
        if respond_to? s
          return send(s)
        end
      end
      nil
    end

    def _alt_count
      [ :t_alt_count, :tumor_alt_count, :alt_count ].each do |s|
        if respond_to? s
          return send(s)
        end
      end
      nil
    end

    def chrom_name
      # properly format the name
      if chromosome =~ /chr/
        chromosome
      else
        "chr#{chromosome}"
      end
    end

    def is_coding?
      variant_classification =~ /(Frame_Shift_Del|Frame_Shift_Ins|In_Frame_Del|In_Frame_Ins|Missense_Mutation|Nonsense_Mutation|Splice_Site|Translation_Start_Site)/
    end

    def gene_name
      if !hugo_symbol || hugo_symbol.size == 0
        onco.txp_gene
      else
        hugo_symbol
      end
    end

    def var_freq
      if !_ref_count.empty? && !_alt_count.empty?
        _ref_count.to_f / (_ref_count.to_i + _alt_count.to_i)
      else
        nil
      end
    end
  end
end
