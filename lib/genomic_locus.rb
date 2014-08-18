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

    def ==(oth)
      raise TypeError unless oth.is_a? GenomicLocus::Position
      chrom == oth.chrom && pos == oth.pos
    end
  end

  class Region
    include GenomicLocus
    attr_reader :chrom, :start, :stop
    def initialize chrom, start, stop
      @chrom, @start, @stop = chrom, start, stop
    end
  end

  def loc
    @loc ||= "#{short_chrom}:#{pos}".to_sym
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

  def method_missing sym, *args, &block
    # provide pos, start, stop if those don't exist
    if sym == :pos && respond_to?(:start)
      start
    elsif sym == :start && respond_to?(:pos)
      pos
    elsif sym == :stop && respond_to?(:ref)
      start + ref.size - 1
    else
      super sym, *args, &block
    end
  end
end
