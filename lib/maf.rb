#!/usr/bin/env ruby

require 'yaml'
require 'mutation_set'

class Maf < Mutation::Collection
  class MafHeader < HashTable::HashHeader
    print_header
    use_sleeve
    requires :Hugo_Symbol => :str, :Entrez_Gene_Id => :str, :Center => :str,
      :NCBI_Build => :str, :Chromosome => :str,
      :Start_Position => :int, :End_Position => :int, :Strand => :str,
      :Variant_Classification => :str, :Variant_Type => :str,
      :Reference_Allele => :str, :Tumor_Seq_Allele1 => :str, :Tumor_Seq_Allele2 => :str,
      :dbSNP_RS => :str, :dbSNP_Val_Status => :str,
      :Tumor_Sample_Barcode => :str, :Matched_Norm_Sample_Barcode => :str,
      :Match_Norm_Seq_Allele1 => :str, :Match_Norm_Seq_Allele2 => :str,
      :Tumor_Validation_Allele1 => :str, :Tumor_Validation_Allele2 => :str,
      :Match_Norm_Validation_Allele1 => :str, :Match_Norm_Validation_Allele2 => :str,
      :Verification_Status => :str, :Validation_Status => :str,
      :Mutation_Status => :str, :Sequencing_Phase => :str, :Sequence_Source => :str,
      :Validation_Method => :str, :Score => :str

    might_have :tumor_var_freq => :float, 
      :tumor_ref_count => :int, :t_ref_count => :int, 
      :normal_ref_count => :int, :n_ref_count => :int,
      :tumor_alt_count => :int, :t_alt_count => :int, 
      :normal_alt_count => :int, :n_alt_count => :int

    def preamble
      "#version 2.2"
    end
  end

  comments "#"

  class Line < Mutation::Record
    alias_key :seqname, :chromosome
    alias_key :pos, :start_position
    alias_key :start, :start_position
    alias_key :stop, :end_position
    alias_key :ref, :reference_allele
    def alt
      tumor_seq_allele1 == reference_allele ? tumor_seq_allele2 : tumor_seq_allele1
    end

    def initialize h, table
      super h, table
      @muts.push Mutation.new(seqname, pos, ref, alt, ref_count, alt_count)
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

    def gene_name
      if !hugo_symbol || hugo_symbol.size == 0
        onco.txp_gene
      else
        hugo_symbol
      end
    end
  end
end
