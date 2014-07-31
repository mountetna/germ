class Mutation
  include GenomicLocus

  # This is a generic description of a mutation.
  VALID_ALLELE = /^[ATGCNatgcn]+$/
  class << self
    def fix_invalid chrom, pos, ref, alt, genome
      if ref =~ VALID_ALLELE && pos =~ VALID_ALLELE
        return new(chrom,pos,ref,alt)
      end
      # At least one is invalid. Add a flanking base
    end
  end

  attr_reader :chrom, :pos, :ref, :alt
  def initialize chrom, pos, ref, alt
    raise "Alleles must not be empty." if ref !~ VALID_ALLELE || alt !~ VALID_ALLELE
    @chrom, @pos, @ref, @alt = chrom, pos, ref, alt
  end

  def ref_at loc
    return nil unless contains? loc
    ref[@pos - loc.pos]
  end

  def alt_at loc
    return nil unless contains? loc
    alt[@pos - loc.pos]
  end

  def start
    @pos
  end

  def stop
    @pos + ref.size - 1
  end
end
