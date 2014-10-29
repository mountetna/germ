require 'genomic_locus'
require 'fasta'
class Mutation
  include GenomicLocus
  # This is a generic description of a mutation.
  VALID_ALLELE = /^[ATGCNatgcn]+$/

  attr_reader :seqname, :pos, :ref, :alt, :ref_count, :alt_count
  alias_method :start, :pos
  def initialize seqname, pos, ref, alt, ref_count=nil, alt_count=nil
    @seqname, @pos, @ref, @alt, @ref_count, @alt_count = seqname, pos, ref, alt, ref_count, alt_count
  end

  def stop
    start + ref.size - 1
  end

  def to_s
    range.to_s + ":#{ref}-#{alt}"
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
