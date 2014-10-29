require 'intervals'
module GenomicLocus
  include IntervalList::Interval
  class Position
    include GenomicLocus
    attr_accessor :seqname, :pos
    def initialize seqname, pos
      @seqname, @pos = seqname, pos
    end

    alias_method :start, :pos
    alias_method :stop, :pos
    def copy
      self.class.new seqname, pos
    end
  end

  class Region
    include GenomicLocus
    attr_accessor :seqname, :start, :stop
    def initialize seqname, start, stop
      @seqname, @start, @stop = seqname, start, stop
    end

    def copy
      self.class.new seqname, start, stop
    end
  end

  def loc
    @loc ||= "#{short_chrom}:#{start}".to_sym
  end

  def default_stop
    # this should always be correct! Even if there is a dash.
    start + ref.size - 1
  end

  def range
    @range ||= "#{short_chrom}:#{start}-#{stop}".to_sym
  end

  def long_chrom
    @long_chrom ||= "chr#{short_chrom}"
  end

  def short_chrom
    @short_chrom ||= seqname.sub(/^chr/,'')
  end
end
