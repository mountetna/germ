#!/usr/bin/env ruby
#
#
# Operations that can be defined on a pair of intervals, yielding a new set of intervals
#
#   - overlap(b) = intersection between a and b, nil if no overlap
#   - a.union(b) = union between a and b, nil if no overlap
#   - a.diff(b) = set of regions of b that do not include a, { b } if no overlap
#
# Operations that can be defined on interval b and set a
#   - a.overlap(b) - set of intervals in a that overlap b
#
# Operations on a set of intervals a
#   - flatten - collapses overlapping intervals
#   - 

module IntervalList
  module Interval
    # this interface needs to implement :seqname, :start, :stop, and :copy
    def clone
      c = copy
      yield c if block_given?
      return c
    end

    def below? interval
      stop < interval.start
    end

    def above? interval
      start > interval.stop
    end

    def overlaps? interval
      seqname == interval.seqname && !below?(interval) && !above?(interval)
    end

    def contains? interval
      if interval.is_a? Numeric
        start <= interval && stop >= interval
      else
        seqname == interval.seqname && start <= interval.start && stop >= interval.stop
      end
    end

    def intersect interval
      return nil if !overlaps? interval

      clone do |c|
        c.seqname = seqname,
        c.start = [ interval.start, start ].max
        c.stop = [ interval.stop, stop ].min
      end
    end

    def diff interval
      ol = overlap interval
      if !ol
        return yield([ self ])
      end
        
      ints = []
      if ol.start > start
        ints.push(clone { |c| c.start = start; c.stop = ol.start-1 })
      end
      if ol.stop < stop
        ints.push(clone { |c| c.start = ol.stop+1; c.stop = stop })
      end
      return yield(ints)
    end

    def union interval
      return nil unless interval && overlaps?(interval)
      clone do |c|
        c.start = [ interval.start, start ].min
        c.stop = [ interval.stop, stop ].max
      end
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
  end
end

module IntervalList
  def overlap interval
    return present([]) unless interval_set[interval.seqname]
    present(interval_set[interval.seqname].overlap interval)
  end

  def nearest interval
    return nil unless interval_set[interval.seqname]
    interval_set[interval.seqname].nearest interval
  end

  def flatten
    current_span = nil
    flat = []
    each do |interval|
      if current_span && current_span.overlaps?(interval)
        current_span.stop = interval.stop if current_span.stop < interval.stop
      else
        # you reached a new span
        if current_span
          yield current_span if block_given?
          flat.push current_span
        end
        current_span = interval.clone
      end
    end
    if current_span
      yield current_span if block_given?
      flat.push current_span
    end
    present flat
  end

  def present obj
    if respond_to? :wrap
      wrap obj
    else
      obj
    end
  end

  def add_interval int
    # don't bother if the tree hasn't been built yet
    @interval_set << int if @interval_set
  end

  def interval_set
    # create a new set of intervals
    @interval_set ||= IntervalList::Set.new self.to_a
  end
end

module IntervalList
  class TreeNode
    attr_reader :max

    def initialize intervals
      # assume they are sorted by start
      
      low, high = intervals.each_slice((intervals.size/2.0).round).to_a

      @node = low.pop
      @left = TreeNode.new low unless low.empty?
      @right = TreeNode.new high unless high.nil?

      update_max
    end

    def add interval
      if interval.start < @node.start
        if @left
          @left.add interval
        else
          @left = TreeNode.new [interval]
        end
      else
        if @right
          @right.add interval
        else
          @right = TreeNode.new [interval]
        end
      end
      update_max
    end

    def update_max
      # set your max to the max of your children
      @max = @node
      @max = @left.max if @left && @left.max.stop > @max.stop
      @max = @right.max if @right && @right.max.stop > @max.stop
    end

    def is_max?
      @max == @node
    end


    def breadth_traverse &block
      @left.breadth_traverse(&block) if @left
      yield @node
      @right.breadth_traverse(&block) if @right
    end

    def depth_traverse &block
      yield @node
      @left.breadth_traverse(&block) if @left
      @right.breadth_traverse(&block) if @right
    end

    def nearest interval
      # if there are overlaps, pick the one with the closest distance
      
      ol = overlap(interval)
      if !ol.empty?
        return ol.min do |a,b|
          interval.dist(a) <=> interval.dist(b)
        end
      end

      # there are no overlaps. Find the highest stop that is less than interval.start
      [ nearest_stop(interval),
        nearest_start(interval) ].compact.min do |a,b|
        interval.dist(a) <=> interval.dist(b)
      end
    end

    def overlap interval
      ols = []
      return ols if interval.start > @max.stop
      ols.concat @left.overlap(interval) if @left
      ols.push @node if @node.overlaps? interval
      ols.concat @right.overlap(interval) if @right && !@node.above?(interval)
      ols
    end
  end
end

module IntervalList
  class Set
    def initialize array
      @seqs = {}
      array.each do |item|
        self << item
      end
    end

    def << item
      @seqs[item.seqname] ||= IntervalList::Tree.new
      @seqs[item.seqname] << item
    end
    def [] ind
      @seqs[ind]
    end
    def each
      @seqs.each do |seq|
        yield seq
      end
    end
    def inspect
      "#<#{self.class}:0x#{'%x' % (object_id << 1)} @seqs=#{@seqs.keys}>"
    end
  end

  class Tree
    def initialize
      @intervals = []
    end

    def << int
      @intervals << int
    end

    def build_tree
      IntervalList::TreeNode.new intervals_start
    end

    def intervals_start
      @intervals_start ||= @intervals.sort_by &:start
    end

    def intervals_stop
      @intervals_stop ||= @intervals.sort_by { |i| -1 * i.stop }
    end

    def nearest interval
      # first see if you have an overlap
      ols = overlap(interval)

      unless ols.empty?
        return ols.min do |int| 
          int.dist(interval)
        end
      end

      # you can just use the sorted intervals to do this
      lowest_start = intervals_start.bsearch do |i|
        i.above? interval
      end
      highest_stop = intervals_stop.bsearch do |i|
        i.below? interval
      end
      [ lowest_start, highest_stop ].compact.min do |i|
        i.dist(interval)
      end
    end

    def tree
      @tree ||= build_tree
    end

    def respond_to_missing? sym, include_all = false
      tree.respond_to?(sym) || super
    end

    def method_missing sym, *args, &block
      tree.send(sym, *args, &block)
    end
  end
end
