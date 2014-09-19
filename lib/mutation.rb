require 'genomic_locus'
require 'fasta'
class Mutation
  include GenomicLocus
  # This is a generic description of a mutation.
  VALID_ALLELE = /^[ATGCNatgcn]+$/

  attr_reader :chrom, :pos, :ref, :alt, :ref_count, :alt_count
  def initialize chrom, pos, ref, alt, ref_count=nil, alt_count=nil
    @chrom, @pos, @ref, @alt, @ref_count, @alt_count = chrom, pos, ref, alt, ref_count, alt_count
  end

  def is_valid?
    ref =~ VALID_ALLELE && alt =~ VALID_ALLELE
  end

  def ref_at loc
    return nil unless contains? loc
    ref[pos - loc.pos]
  end

  def var_freq
    if ref_count && alt_count
      ref_count / alt_count
    end
  end

  def alt_at loc
    return nil unless contains? loc
    alt[pos - loc.pos]
  end
end
