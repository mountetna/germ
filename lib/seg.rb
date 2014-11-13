require 'hash_table'
require 'genomic_locus'

class SegFile < HashTable
  include IntervalList
  def initialize obj=nil, opts={}
    opts = opts.merge(:header => { :sample_name => :str, :chromosome => :str,
                                   :start => :int, :stop => :int, 
                                   :num_probes => :int, :segment_mean => :float }, 
                      :skip_header => :true, :idx => :sample_name)
    super obj, opts
  end
  class Segment < HashLine
    include GenomicLocus
    alias_key :seqname, :chromosome
    def copy
      self.class.new @hash.clone, @table
    end
  end
  line_class Segment
end
