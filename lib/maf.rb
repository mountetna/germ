#!/usr/bin/env ruby

require 'yaml'
require 'mutation_set'

class Maf < Mutation::Collection
  header_on
  requires :hugo_symbol => :str, :entrez_gene_id => :str, :center => :str,
    :ncbi_build => :str, :chromosome => :str,
    :start_position => :int, :end_position => :int, :strand => :str,
    :variant_classification => :str, :variant_type => :str,
    :reference_allele => :str, :tumor_seq_allele1 => :str, :tumor_seq_allele2 => :str,
    :dbsnp_rs => :str, :dbsnp_val_status => :str,
    :tumor_sample_barcode => :str, :matched_norm_sample_barcode => :str,
    :match_norm_seq_allele1 => :str, :match_norm_seq_allele2 => :str,
    :tumor_validation_allele1 => :str, :tumor_validation_allele2 => :str,
    :match_norm_validation_allele1 => :str, :match_norm_validation_allele2 => :str,
    :verification_status => :str, :validation_status => :str,
    :mutation_status => :str, :sequencing_phase => :str, :sequence_source => :str,
    :validation_method => :str, :score => :str
  might_have :tumor_var_freq => :float, 
    :tumor_ref_count => :int, :t_ref_count => :int, 
    :normal_ref_count => :int, :n_ref_count => :int,
    :tumor_alt_count => :int, :t_alt_count => :int, 
    :normal_alt_count => :int, :n_alt_count => :int
  comments "#"

  def preamble
    "#version 2.2"
  end

  class Line < Mutation::Record
    alias_key :chrom, :chromosome
    alias_key :pos, :start_position
    alias_key :start, :start_position
    alias_key :stop, :end_position
    alias_key :ref, :reference_allele
    def alt
      tumor_seq_allele1 == reference_allele ? tumor_seq_allele2 : tumor_seq_allele1
    end

    def initialize h, table
      super h, table
      @muts.push Mutation.new(chrom, pos, ref, alt, ref_count, alt_count)
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
  line_class Maf::Line
end
