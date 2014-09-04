require 'intervals'
module GenomicLocus
  include IntervalList::Interval
  class Position
    include GenomicLocus
    attr_reader :chrom, :pos
    def initialize chrom, pos
      @chrom, @pos = chrom, pos
    end

    alias_method :start, :pos
    alias_method :stop, :pos
    alias_method :seqname, :chrom
  end

  class Region
    include GenomicLocus
    attr_reader :chrom, :start, :stop
    alias_method :seqname, :chrom
    def initialize chrom, start, stop
      @chrom, @start, @stop = chrom, start, stop
    end
  end

  def loc
    @loc ||= "#{short_chrom}:#{start}".to_sym
  end

  def range
    @range ||= "#{short_chrom}:#{start}-#{stop}".to_sym
  end

  def long_chrom
    @long_chrom ||= "chr#{short_chrom}"
  end

  def short_chrom
    @short_chrom ||= chrom.sub(/^chr/,'')
  end
end
