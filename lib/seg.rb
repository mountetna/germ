require 'hash_table'
require 'genomic_locus'

class Seg < HashTable
  include IntervalList
  columns :id, :chrom, :loc_start, :loc_end, :num_mark, :seg_mean
  types chrom: :int, loc_start: :int, loc_end: :int, num_mark: :int, seg_mean: :float
  display_names id: :ID, loc_start: :"loc.start", loc_end: :"loc.end", num_mark: :"num.mark", seg_mean: :"seg.mean"
  index :id
  parse_mode :orig
  print_columns

  class Segment < HashTable::Row
    include GenomicLocus
    alias_key :seqname, :chrom
    alias_key :stop, :end
    def copy
      default_copy
    end
  end
end
