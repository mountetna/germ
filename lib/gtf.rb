require 'hash_table'
require 'intervals'

class GTF < HashTable
  header_off

  class GTFLine < HashTable::HashLine
    include IntervalList::Interval
    def chrom; seqname; end
    def chrom= nc; seqname = nc; end
    def copy
      c = self.class.new @hash.clone
    end
  end
  line_class GTFLine

  class Gene
    class Transcript
      attr_reader :name, :intervals, :introns
      def initialize array, name
        @intervals = array
        @name = name

        @transcript = @intervals.find{|t| t.feature == "transcript"}

        build_introns
      end

      def site pos
        i = @transcript.clone :pos => pos
        intron = nil
        overlaps = @intervals.select{|f| f.contains? i }
        return cds_pos i if overlaps.find{|f| f.feature == "cds" }
        return intron_pos intron if intron = overlaps.find{|f| f.feature == "intron" }
        return { :type => :utr } if overlaps.find{|f| f.feature =~ /UTR/ }
        { :type => :transcript }
      end

      def intron_frame intron
        # find the terminal frame of the leading exon
        if strand == "+"
          (intron.prev_exon.frame + intron.prev_exon.size)%3
        else
          intron.post_exon.frame
        end
      end

      def cds_pos pos
        bases = 0
        if @strand == "+"
          cds.each do |c|
            if c.contains? pos
              bases += pos - c.start + 1
              break
            else
              bases += c.size
            end
          end
        else
          cds.reverse.each do |c|
            if c.contains? pos
              bases += c.stop - pos + 1
              break
            else
              bases += c.size
            end
          end
        end
        { :type => :cds, :pos => bases/3 }
      end

      def intron_pos intron
        { :type => :intron, :pos => cds_pos(intron.start-1), :frame => intron_frame(intron) }
      end

      def utr3
        return @utr3 if @utr3
        cs = strand == "+" ? cds.first : cds.last
        @utr3 = exons.select{ |e| strand == "+" ? !e.above?(cs) : !e.below?(cs) }
          .map{|e| e.strict_diff(cs) }
          .compact.map(&:to_a)
        @utr3.each do |u|
          u.feature = "3' UTR"
        end
      end

      def utr5
        return @utr5 if @utr5
        cs = strand == "+" ? cds.last : cds.first
        @utr5 = exons.select{|e| strand == "+" ? !e.below?(cs) : !e.above?(cs) }
          .map{|e| e.strict_diff(cs)}
          .compact.map(&:to_a)
        @utr5.each do |u|
          u.feature = "5' UTR"
        end
      end

      def build_introns
        return if !exons
        @introns = exons.map.with_index do |e1,i|
          e2 = @exons[i+1]
          next if !e2
          intron = e1.clone(:start => e1.stop+1, :stop => e2.start-1)
          intron.feature = "intron"
          intron.prev_exon = e1
          intron.post_exon = e2
          intron
        end.compact
        @intervals.concat @introns
      end

      def build_utrs
        @intervals.concat @utr3 if @utr3
        @intervals.concat @utr5 if @utr5
      end

      def start
        @transcript.start
      end
      def stop
        @transcript.stop
      end
      def strand
        @transcript.strand
      end
      def contains? pos
        start <= pos && stop >= pos
      end
      def exons
        @exons ||= @intervals.select{|e| e.feature == "exon"}.sort_by &:start
      end
      def cds
        @cds ||= @intervals.select{|e| e.feature == "CDS"}.sort_by &:start
      end
    end

    attr_reader :name, :strand, :transcripts, :intervals
    def initialize array
      @intervals = array
      @gene = @intervals.find{|l| l.feature == "gene"}
      @name = @gene.attribute[:gene_name]
      @strand = @gene.strand
      @transcripts = build_transcripts
    end

    def start
      @gene.start
    end
    def stop
      @gene.stop
    end

    def site pos
      score = { :cds => 1, :exon => 2, :utr => 3, :intron => 4, :transcript => 5, :igr => 6 }
      sites = @transcripts.map do |t|
        t.site(pos) if t.contains? pos
      end.compact
      sites.push(:type => :igr)
      sites.sort_by{|s| score[s[:type]] }.first
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @transcripts=#{@transcripts.count}>"
    end

    private
    def build_transcripts
      (@intervals.select{|l| l.feature == "transcript"} || []).map do |t|
        name = t.attribute[:transcript_name]
        Transcript.new @intervals.select{|l| l.attribute[:transcript_name] == name}, name
      end
    end
  end

  def gene name
    intervals = gene_name[name]
    GTF::Gene.new intervals if intervals
  end

  def initialize file, opts=nil
    opts = { :comment => "#", :sep => " "}.merge(opts || {})

    @sep = opts[:sep]

    super file, :comment => opts[:comment], :idx => opts[:idx],
      :header => [ :seqname, :source, :feature, :start, :stop, :score, :strand, :frame, :attribute ],
      :types => [ :str, :str, :str, :int, :int, :int, :str, :int, [ ";", @sep ] ]
  end

  def inspect
    "#<#{self.class}:0x#{'%x' % (object_id << 1)} @lines=#{@lines.count}>"
  end

  def to_interval_list
    IntervalList.new self
  end

  def format_line g
    [ :seqname, :source, :feature, :start, :stop, :score, :strand, :frame, :attribute ].map do |h|
      if h == :attribute
        g[:attribute].map do |k,v| 
          "#{k}#{@sep}#{v}" 
        end.join("; ")
      else
        g[h]
      end
    end.join("\t")
  end

  protected
  def add_index line
    @index.each do |key,ind|
      ikey = line[key] || line[:attribute][key]
      next if !ikey
      (ind[ ikey ] ||= []) << line
    end
  end
end
