#!/usr/bin/env ruby
require 'fasta_aux/fasta_aux'

class Fasta
  private
  include FastaAux

  class Chrom
    attr_reader :name, :size, :start
    def initialize n, fasta, sz, st
      @name, @fasta, @size, @start = n, fasta, sz, st
    end

    def include? pos
      if pos.is_a? Array
        start,stop = pos.to_a
        include?(start) && include?(stop)
      else
        pos.is_a?(Fixnum) && pos >= 1 && pos <= size
      end
    end

    def file_pos pos
      return nil if !include? pos
      start + pos/line_size*(line_size+1) + (pos % line_size) - 1 - ((pos % line_size == 0) ? 1 : 0)
    end

    private
    def line_size
      @fasta.line_size
    end
  end

  def seq_size_from_byte_size bytes
    (bytes/(@line_size+1))*@line_size + (bytes % (@line_size+1))
  end

  def compute_chrom_stats
    @chroms = {}
    @seq_names.each_with_index do |name, i|
      if i < @seq_names.size-1
        @chroms[name] = Fasta::Chrom.new name, self, seq_size_from_byte_size(@seq_starts[i+1] - @seq_starts[i] - @seq_names[i+1].size - 3), @seq_starts[i]
      else
        @chroms[name] = Fasta::Chrom.new name, self, seq_size_from_byte_size(@io.size - @seq_starts[i]), @seq_starts[i]
      end
    end
  end


  public
  attr_reader :line_size
  def initialize file, size=nil
    @io = File.open(file)

    @line_size = size || 50

    get_seq_starts

    compute_chrom_stats
  end

  def size
    @chroms.inject(0) { |s,v| s += v.last.size }
  end

  def inspect
    "#<#{self.class.name}:#{object_id} @chroms=#{@seq_names}>"
  end

  def get_seq chrom, start, stop
    raise ArgumentError.new("Improper interval") if !@chroms[chrom] || !@chroms[chrom].include?([start,stop])
    get_seq_chunk(@chroms[chrom].file_pos(start), @chroms[chrom].file_pos(stop)).gsub(/\n/,'')
  end
end
