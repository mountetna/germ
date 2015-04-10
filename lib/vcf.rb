require 'hash_table'
require 'genomic_locus'

class VCF < HashTable
  columns :chrom, :pos, :id, :ref, :alt, :qual, :filter, :info
  required :chrom, :pos, :id, :ref, :alt, :qual, :filter, :info
  display_names :chrom => :"#CHROM", :pos => :POS, :id => :ID, :ref => :REF,
    :alt => :ALT, :qual => :QUAL, :filter => :FILTER, :info => :INFO
  types :pos => :int, :info => [ ";", "=" ], :format => [ ":" ]
  parse_mode :parsed
  print_columns
  comment "##"

  def samples
    @samples ||= get_samples
  end

  def add_sample *samps
    samples.concat samps

    add_sample_types samps

    samps
  end
  alias_method :add_samples, :add_sample

  class << self
    def genotype_class
      @genotype_class ||= find_descendant_class VCF::Genotype
    end
  end

  protected
  def get_samples
    samples = columns.size > required.size ?  columns - required - [ :format ] : []

    add_sample_types samples

    samples
  end

  def set_parsed_columns columns
    cols = super columns
    
    samples

    cols
  end

  def add_sample_types samps
    samps.each do |sample|
      @types[sample] = [ ":" ]
    end
  end

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

  class Line < HashTable::Row
    include GenomicLocus
    alias_key :seqname, :chrom
    alias_key :start, :pos
    alias_key :stop, :default_stop
    def initialize(h, s)
      super h, s

      build_genotypes
    end

    def build_genotypes
      @genotypes = {}
      @table.samples.each do |s|
        @genotypes[s] = @table.class.genotype_class.new self, self.send(s)
        @genotypes[@table.display_names[s]] = @genotypes[s]
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

    def variant_type
      if ref.length == alt.length
        if ref.size > 1
          :ONP
        else
          :SNP
        end
      else
        if ref.length < alt.length
          :INS
        else
          :DEL
        end
      end
    end

    def format_symbols
      self.format.map do |f|
        f.downcase.to_sym
      end
    end

    def format
      @hash[:format]
    end
  end

  class Genotype
    def initialize(line,field)
      @line = line
      @hash = Hash[line.format_symbols.zip(field)]
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

    def respond_to_missing? sym, include_all = false
      @hash[sym] || super
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

    def to_s
      @line.format_symbols.map{|f| send f}.join(":")
    end
  end
end
