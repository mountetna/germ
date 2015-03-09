require 'hash_table'
require 'genomic_locus'

class SegFile < HashTable
  include IntervalList
  class SegHeader < HashTable::HashHeader
    requires Sample: :str, Chromosome: :str, Start: :int, End: :int, Num_Probes: :int, Segment_Mean: :float
    use_sleeve
    replace_columns
    print_header
  end
  class SegIndex < HashTable::HashIndex
    always_index :sample
  end
  def initialize obj=nil, opts={}
    opts = opts.merge(:skip_header => :true, :idx => :sample)
    super obj, opts
  end
  class Segment < HashLine
    include GenomicLocus
    alias_key :seqname, :chromosome
    alias_key :stop, :end
    def copy
      self.class.new @hash.clone, @table
    end
  end
end
