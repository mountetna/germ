require 'germ/data_types'
require 'germ/printer'
class Sam
  include Enumerable
  include Printer

  class Header
    class Record
      attr_reader :type
      attr_reader :tags
      attr_reader :comment
      attr_reader :line

      def initialize line
        @line = line
        if line =~ /^@CO\t(.*)/
          @type = :CO
          @comment = $1
        end
        line.match /^@([A-Za-z][A-Za-z])\t((?:[A-Za-z][A-Za-z0-9]:[ -~]+(?:\t|$))+)/ do |m|
          @type = m[1].to_sym
          @tags = Hash[m[2].split(/\t/).map{|s| s.split(/:/)}]
        end
      end

      def to_s
        if @type == :CO
          "@#{@type}\t#{@comment}"
        else
          "@#{@type}\t#{tags.map{ |t,v| "#{t}:#{v}" }.join("\t")}"
        end
      end
    end

    attr_reader :records
    def initialize sam, lines
      @sam = sam
      @records = []
      lines.each do |l|
        @records.push Sam::Header::Record.new(l)
      end
    end

    def output f
      @records.each do |r|
        f.puts r
      end
    end
  end

  class Read
    extend DataTypes
    attr_sym :qname
    attr_integer :flag, :pos, :mapq, :pnext, :tlen
    attr_string :rname, :rnext, :other, :sam, :seq, :qual, :cigar_string
    alias :chrom :rname
    alias :start_pos :pos
    alias :mate_pos :pnext

    def cigar
      @cigar ||= @cigar_string.scan(/(\d+)(\w)/)
    end

    def paired?;  flag & 1; end
    def mapped?;  flag & 2; end
    def unmapped?;  flag & 4; end
    def mate_unmapped?; flag & 8; end
    def reversed?; flag & 16; end
    def mate_reversed?; flag & 32; end
    def first?; flag & 64; end
    def second?; flag & 128; end
    def secondary?; flag & 258; end
    def unchaste?; flag & 512; end
    def supplementary?; flag & 1024; end

    def end_pos
      epos = pos
      cigar.each do |w,c|
        case c
        when 'M', 'D', 'N', '=', 'X'
          epos += w.to_i
        end
      end
      epos
    end

    def seq_at p
      cpos = pos
      cind = 0
      cigar.each do |w,c|
        case c
        when 'M', '=', 'X'
          epos = cpos + w.to_i
          if (cpos...epos).include? p
            return seq[cind + p - cpos]
          end
          cind = cind + w.to_i
          cpos = epos
        when 'D', 'N'
          epos = cpos + w.to_i
          if (cpos...epos).include? p
            return nil
          end
          cind = cind + w.to_i
          cpos = epos
        when 'I'
          cind = cind + w.to_i
        when 'S', 'H', 'P'
          return nil
        end
      end
      nil
    end

    def junctions
      epos = pos
      cigar.map do |w,c|
        case c
        when 'M', 'D', '=', 'X'
          epos += w.to_i
          nil
        when 'N'
          [ epos-1, epos += w.to_i ]
        end
      end.compact
    end

    def mate_chrom
      if rnext == "="
        chrom
      else
        rnext
      end
    end

    def mate
      sam.mates[qname].find{|l| l.pos == mate_pos}
    end

    def initialize s, fields
      @sam = s
      @header = [:qname, :flag, :rname, :pos, :mapq, :cigar_string, :rnext, :pnext, :tlen, :seq, :qual, :other]
      @header.each_with_index do |s,i|
        send "#{s}=".to_sym, fields[i]
      end
      sam.add_mate qname, self
    end

    def output f
      f.puts [ @qname, @flag, @rname, @pos, @mapq, @cigar_string, @rnext, @pnext, @tlen, @seq, @qual, @other].join("\t")
    end
  end

  attr_reader :reads, :mates
  attr_accessor :header
  def initialize
    @reads = []
    @mates = {}
  end

  def add_mate mate, record
    @mates[mate] ||= []
    @mates[mate].push record
  end

  def each
    @reads.each do |r|
      yield r
    end
  end

  def self.read file
    sam = self.new
    header = []
    File.foreach(file) do |l|
      if l =~ /^@/
        header.push l
        next
      end
      sam.reads.push Sam::Read.new(sam, l.chomp.split(/\t/,12))
    end
    sam.header = Sam::Header.new(sam, header)
    sam
  end

  def output f
    @header.output f
    @reads.each do |r|
      r.output f
    end
  end

  def inspect
    "#<#{self.class.name}:#{object_id} @reads=#{reads.size}>"
  end
end
