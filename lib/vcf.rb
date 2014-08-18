require 'mutation_set'
require 'yaml'

class VCF < Mutation::Collection
  header_on
  requires :chrom => :str, :pos => :int, :id => :str, :ref => :str, 
    :alt => :str, :qual => :str, :filter => :str, :info => [ ";", "=" ]
  might_have :format => :str
  comments "##"
  attr_reader :samples

  class Preamble
    def initialize lines
      @items = {}
      lines.each do |line|
        add_key line.chomp
      end
    end

    protected
    def add_key line
      line.match(/^##(?<key>\w+)=(?<value>.*)$/) do |m|
        add_key_item m[:key].to_sym, m[:value]
      end
    end

    def add_key_item key, value
      @items[key] ||= []
      @items[key].push new_item(value)
    end

    def new_item value
      case value
      when /^<(.*)>$/
        Hash[$1.split(/,/).map{|s| s.split(/=/)}]
      else
        value
      end
    end
  end

  def enforce_header
    # kludge for empty vcf with no format line
    super

    if header.size > required.size
      @samples = @header - required - [ :format ]
      # recover the original sample name from the sleeve
      new_samples = @samples.map do |s|
        @sleeve[s].to_sym
      end
      @header = @header - @samples + new_samples
      @samples = new_samples
    end
  end

  class Line < Mutation::Record
    def initialize(h, s)
      super h, s

      self.format = self.format.split(/:/).map{|f| f.to_sym} if self.format

      build_genotypes
      build_muts
    end

    def build_genotypes
      @genotypes = {}
      if @table.samples
        @table.samples.each do |s|
          @genotypes[s] = VCF::Genotype.new self, self.send(s)
        end
      end
    end

    def build_muts
      @table.samples.each do |s|
        @muts.push Mutation.new(chrom, pos, ref, alt, genotype(s).ref_count, genotype(s).alt_count)
      end
    end

    def skip_genotype? g
      name, geno = g.first
      geno = genotype(geno)

      !geno || geno.empty? || criteria_failed?(geno, name)
    end

    def pick_alt
      alt.split(/,/).first
    end

    def format_column column
      if column == :format
        self.format.join(":")
      elsif genotype(column)
        genotype(column).to_s
      else
        super(column)
      end
    end

    def genotype(s)
      @genotypes[s] if @genotypes
    end
  end
  line_class VCF::Line

  class Genotype
    def initialize(line,field)
      @line = line
      @hash = Hash[line.format.map(&:downcase).zip(field.split /:/)]
    end

    def method_missing sym, *args, &block
      if @hash[sym]
        @hash[sym]
      elsif sym.to_s =~ /(.*)=/ 
        @hash[$1.to_sym] = args.first
      else
        super sym, *args, &block
      end
    end

    def respond_to? sym
      @hash[sym] || super(sym)
    end

    def homozygous?
      gt =~ /0.0/ || gt =~ /1.1/
    end

    def heterozygous?
      gt =~ /0.1/ || gt =~ /1.0/
    end

    def empty?
      gt =~ /\..\./
    end

    def callable?
      gt !~ /\..\./
    end

    def approx_depth; dp.to_i; end
    def depth; alt_count + ref_count; end
    def alt_count; @alt_count ||= respond_to?(:ad) ? ad.split(/,/)[1].to_i : nil; end
    def ref_count; @ref_count ||= respond_to?(:ad) ? ad.split(/,/)[0].to_i : nil; end
    def alt_freq; alt_count / depth.to_f; end
    def ref_freq; ref_count / depth.to_f; end
    def ref_length; @line.ref.length; end
    def alt_length; @line.alt.length; end
    def alt_base_quality; respond_to?(:nqsbq) ? nqsbq.split(/,/)[0].to_f : nil; end
    def alt_map_quality; respond_to?(:mqs) ? mqs.split(/,/)[0].to_f : nil; end
    def alt_mismatch_rate; respond_to?(:nqsmm) ? nqsmm.split(/,/)[0].to_f : nil; end
    def alt_mismatch_count; respond_to?(:mm) ? mm.split(/,/)[0].to_f : nil; end
    def quality; gq.to_i; end

    def to_s
      @line.format.map(&:downcase).map{|f| @hash[f]}.join(":")
    end
  end
end
