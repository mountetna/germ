#!/usr/bin/env ruby

class IntervalList
  include Enumerable
  class OrderedList
    include Enumerable
    def initialize ints
      @track = ints
    end

    def each
      @track.each do |t|
        yield t
      end
    end

    def intersect interval
      ovs = overlap interval
      return nil if !ovs
      ovs.map{|s| s.strict_overlap interval }
    end
    
    def overlap interval
      # first, find the lowest interval that is not below the given interval
      low = (0...@track.size).bsearch do |i|
        !@track[i].below? interval
      end
      # if low is nil, all of the intervals are below the search
      # otherwise, low might be the first interval
      return nil if !low || (low == 0 && @track[low].above?(interval))

      # now you have a real value on the low end!
      # get the first guy who is above the interval
      high = (0...@track.size).bsearch do |i|
        @track[i].above? interval
      end
      # if nil, all of these guys are not above the interval
      high = high ? high - 1 : @track.size-1
      o = @track[ low..high ]
      o.empty? ? nil : o
    end

    def nearest interval
      # find the first guy who is above the interval
      low = (0...@track.size).bsearch do |i|
        !@track[i].below? interval
      end

      return @track.last if !low
      return @track[low] if low == 0
      prev = @track[ low - 1]
      @track[low].dist(interval) > prev.dist(interval) ? prev : @track[low]
    end
  end
  class BinaryTree
    attr_reader :max
    def self.create intervals
      new intervals.sort_by(&:start)
    end
    def initialize intervals
      # assume they are sorted by start
      low, high = intervals.each_slice((intervals.size/2.0).round).to_a
      @node = low.pop
      @left = BinaryTree.new low unless low.empty?
      @right = BinaryTree.new high unless high.nil?
      update_max
    end

    def update_max
      # set your max to the max of your children
      @max = @node.stop
      @max = @left.max if @left && @left.max > @max
      @max = @right.max if @right && @right.max > @max
    end

    def nearest interval
      # 
    end

    def overlap interval
      ols = []
      return ols if interval.start > @max
      ols.concat @left.overlap(interval) if @left
      ols.push @node if @node.overlaps? interval
      ols.concat @right.overlap(interval) if @right && !@node.above?(interval)
      ols
    end
  end
  class Tree
    def self.create intervals
      new intervals.sort_by(&:start), intervals.sort_by(&:stop)
    end
    def initialize starts, stops
      # find the midpoint
      midp = (starts.first.start + stops.last.stop) / 2
      @mid = starts.clone :pos => midp

      l = left_tree starts, stops
      r = right_tree starts, stops
      @left = IntervalList::Tree.new *l unless l.first.empty?
      @right = IntervalList::Tree.new *r unless r.first.empty?
      @center_start = starts - l.first - r.first
      @center_stop = stops - l.last - r.last
    end

    private
    def left_tree starts, stops
      low = (0...stops.size).bsearch do |i|
        !stops[i].below? @mid
      end
      left_stops = (low == 0 ? [] : stops[0..low-1])
      return [ [], [] ] if left_stops.empty?
      left_starts = starts & left_stops
      [ left_stops, left_starts ]
    end

    def right_tree starts, stops
      low = (0...starts.size).bsearch do |i|
        starts[i].above? @mid
      end
      right_starts = (!low ? [] : starts[low..-1])
      return [ [], [] ] if right_starts.empty?
      right_stops = stops & right_starts
      [ right_starts, right_stops ]
    end
  end
  module Interval
    # this interface needs to implement :chrom, :start, :stop, and :clone
    def clone opts={}
      c = copy
      c.chrom = opts[:chrom] if opts[:chrom]
      c.start = opts[:start] if opts[:start]
      c.stop = opts[:stop] if opts[:stop]
      c.start = opts[:pos] if opts[:pos]
      c.stop = opts[:pos] if opts[:pos]
      return c
    end
    #def start= ns; @start = ns; end
    #def stop= ns; @stop = ns; end

    def below? interval
      stop < interval.start
    end

    def above? interval
      start > interval.stop
    end

    def overlaps? interval
      chrom == interval.chrom && !below?(interval) && !above?(interval)
    end

    def contains? interval
      if interval.is_a? Numeric
        start <= interval && stop >= interval
      else
        chrom == interval.chrom && start <= interval.start && stop >= interval.stop
      end
    end

    def strict_overlap interval
      return nil if !overlaps? interval

      clone chrom, [ interval.start, start ].max, [ interval.stop, stop ].min
    end

    def strict_diff interval
      ol = strict_overlap interval
      return IntervalList.new [ self ] if !ol
      ints = []
      if ol.start > start
        ints.push clone( :start => start, :stop => ol.start-1 )
      end
      if ol.stop < stop
        ints.push clone(:start => ol.stop+1, :stop => stop)
      end
      if !ints.empty?
        return IntervalList.new ints
      end
    end

    def strict_union interval
      return nil unless interval && overlaps?(interval)
      clone :start => [ interval.start, start ].min, :stop => [ interval.stop, stop ].max
    end

    def overlap interval_list
      interval_list.overlap self
    end

    def nearest interval_list
      interval_list.nearest self
    end

    def intersect interval_list
      interval_list.intersect self
    end

    def size
      stop - start + 1
    end

    def center
      (stop + start)/2.0
    end

    def dist interval
      (center-interval.center).abs
    end

    def intersection_size interval_list
      return 0 if !inters = intersect(interval_list)
      inters.inject(0) {|sum,int| sum += int.size}
    end
  end
  class BasicInterval
    include Interval

    attr_accessor :chrom, :start, :stop, :data

    def initialize opts
      @chrom = opts[:chrom]
      @start = opts[:start]
      @stop = opts[:stop]
      @stop = @start = opts[:pos] if opts[:pos]
      @data = opts[:data]
    end
    def copy
      self.class.new :chrom => @chrom, :start => @start, :stop => @stop, :data => @data
    end
    def inspect
      "#<#{self.class}:0x#{'%x' % (object_id << 1)} @chrom=#{@chrom} @start=#{@start} @stop=#{@stop}>"
    end
  end

  def each
    @intervals.each do |int|
      yield int
    end
  end

  def overlap interval
    track = @ints_chrom[interval.chrom]
    return nil if !track
    track.overlap interval
  end

  def nearest interval
    track = @ints_chrom[interval.chrom]
    return nil if !track
    track.nearest interval
  end

  def intersect interval
    track = @ints_chrom[interval.chrom]
    return nil if !track
    track.intersect interval
  end

  # subtract this set of intervals from the given interval_list
  def diff interval_list
    interval_list.map do |int|
      ols = overlap(int)
      # if there are no overlaps, return int
      unless ols
        int
      else
        int = ols.each do |ol|
          int.strict_diff(ol).to_a
        end.flatten
      end
    end
  end

  def initialize array, opts = {}
    @intervals = []
    @ints_chrom = {}
    array.each do |item|
      if item.is_a? IntervalList::Interval
        int = item
      end
      @intervals.push int
      @ints_chrom[int.chrom] ||= []
      @ints_chrom[int.chrom].push int
    end

    sort_ints_chrom opts[:type]
  end

  def inspect
    "#<#{self.class}:0x#{'%x' % (object_id << 1)} @intervals=#{@intervals.size}>"
  end

  attr_reader :ints_chrom

  def collapse!
    # collapse this set of intervals down to a shorter one
    @ints_chrom.each do |chrom,list|
      @ints_chrom[chrom] = collapsed_list list
    end

    @intervals = @ints_chrom.map(&:last).flatten
    self
  end

  private
  def collapsed_list intervals
    new_list = []
    cache_interval = nil
    intervals.each do |interval|
      # it should be sorted already
      if cache_interval
        if !un = cache_interval.strict_union(interval)
          new_list.push cache_interval
          cache_interval = interval
        else
          cache_interval = un
        end
      else
        cache_interval = interval 
      end
    end
    new_list.push cache_interval if cache_interval
    new_list
  end

  def sort_ints_chrom type
    @ints_chrom.each do |chrom,list|
      case type
      when nil, :btree
      @ints_chrom[chrom] = IntervalList::BinaryTree.new list.sort_by{ |int| int.start }
      when :flat
      @ints_chrom[chrom] = IntervalList::OrderedList.new list.sort_by{ |int| int.start }
      end
    end
  end
end
