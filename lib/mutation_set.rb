require 'oncotator'
require 'yaml'
require 'intervals'

class Mutation
  module Oncotator
    def onco
      raise ArgumentError, @onco_error unless valid_onco_input?
      @onco ||= Oncotator.new :key => to_ot
    end

    def discard_onco
      @onco = nil
    end

    def skip_oncotator? criteria=nil
      return true if !onco || onco.empty? || criteria_failed?(onco, criteria || :oncotator)
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @mutation=#{@mutation}>"
    end

    def in_cosmic
      onco.Cosmic_overlapping_mutations ? "YES" : "NO"
    end

    def to_ot
      [ short_chrom, start, stop, ref_allele, alt_allele ].join("_")
    end

    private
    CHROM_POS=/^[0-9]+$/
    ALLELE_SEQ=/^([A-Z]+|-)$/
    def valid_onco_input?
      @onco_error = []
      @onco_error.push 'Malformed start position' unless start.to_s =~ MutationSet::Line::CHROM_POS
      @onco_error.push 'Malformed stop position' unless stop.to_s =~ MutationSet::Line::CHROM_POS
      @onco_error.push 'Malformed reference allele' unless ref_allele =~ MutationSet::Line::ALLELE_SEQ
      @onco_error.push 'Malformed alt allele' unless alt_allele =~ MutationSet::Line::ALLELE_SEQ
      @onco_error.empty?
    end
  end
  module Filtering
    def criteria_failed? obj, name
      return nil if !collection.mutation_config
      name = [ name ] if !name.is_a? Array
      crit = name.reduce(collection.mutation_config) do |h,n|
        h.is_a?(Hash) ? h[n] : nil
      end
      return nil if !crit
      crit.each do |attrib,value|
        return true if !criterion_ok? obj, attrib, value
      end
      nil
    end

    def criterion_ok? obj, attrib, value
      case attrib
      when /^min_(.*)/
        v = obj.send($1.to_sym).to_f
        return v >= value.to_f
      when /^max_(.*)/
        return obj.send($1.to_sym).to_f <= value.to_f
      when /^exclude_(.*)/
        v = obj.send($1.to_sym)
        if value.is_a? Array
          return value.none? { |r| v.match(/#{r}/) }
        else
          return v !~ /#{value}/
        end
      when /^has_(.*)/
        v = obj.send($1.to_sym)
        if value.is_a? Array
          return value.include? v
        elsif value == true
          return v && (v.is_a?(String) ? v.size > 0 : v)
        elsif value == false || value == "nil"
          return !v
        else
          return value == v
        end
      when /^include_(.*)/
        v = obj.send($1.to_sym)
        if value.is_a? Array
          return value.any? { |r| v.match(/#{r}/) }
        else
          return v =~ /#{value}/
        end
      when /^either.*/
        v = nil
        value.each do |attrib,val|
          v = true if criterion_ok? obj, attrib, val
        end
        return v
      when /^whitelisted/
        whitelist = collection.whitelist value
        return whitelist.intersect(self)
      when /^blacklisted/
        blacklist = collection.blacklist value
        return !blacklist.intersect(self)
      else
        # send it
        case value
        when "nil", false, nil
        return !obj.send(attrib.to_sym)
        when true
        return obj.send(attrib.to_sym)
        end
      end
      true
    end
  end
end

class Mutation
  class Record < HashLine
    include IntervalList::Interval
    attr_reader :collection

    def self.alias_key sym1, sym2
      define_method sym1 do
        send sym2
      end
      define_method "#{sym1}=" do |v|
        send "#{sym2}=", v
      end
    end

    def copy
      self.class.new @hash.clone, collection
    end

    def initialize(fields, collection)
      @collection = collection
      super fields
    end

    def key
      "#{chrom}:#{start}:#{stop}"
    end

    def to_s
      collection.clean_headers.map{ |h| @mutation[h] }.join("\t")
    end

    def to_hash
      @mutation
      #Hash[@mutation.map do |k,v| [ k, v ? v.clone : v ]; end]
    end

    def method_missing(meth,*args,&block)
      if meth.to_s =~ /(.*)=/ 
        @mutation[$1.to_sym] = args.first
      else
        @mutation.has_key?(meth.to_sym) ? @mutation[meth.to_sym] : super
      end
    end

    def respond_to? method
      !@mutation[method.to_sym].nil? || super
    end
  end

  class Collection
    include Enumerable
    attr_reader :mutation_config, :lines, :preamble_lines
    attr_accessor :headers
    class << self
      attr_reader :required, :comment
      def requires *terms
        @required = terms
      end

      def comments c
        @comment = c
      end

      def read(filename,mutation_config=nil)
        set = new mutation_config, true

        set.load_file filename

        return set
      end
    end

    def load_file filename
      File.foreach(filename) do |l|
        fields = l.chomp.split(/\t/,-1)
        if !headers
          if fields.first.downcase == required.first.downcase
            enforce_headers fields
          else
            preamble_lines.push l
          end
          next
        end
        add_line fields
      end

      post_read_hook
    end

    def preamble
      preamble_lines.join("")
    end

    def write file
      File.open(file,"w") do |f|
        output f
      end
    end

    def print f=nil
      if f
        write f
      else
        output STDOUT
      end
    end

    def output f
      f.puts preamble
      f.puts headers.join("\t")
      @lines.each do |l|
        l = yield l if block_given?
        next if !l || l.invalid?
        f.puts format_line(l)
      end
    end

    def format_line l
      l.to_s
    end

    def clean_header s
      s.to_s.gsub(/\s+/,"_").gsub(/[^\w]+/,"").downcase.to_sym
    end

    def clean_headers
      @headers.map {|h| clean_header h}
    end

    def add_line fields
      @lines.push self.class.const_get(:Line).new(clean_fields(fields), self)

      index_line @lines.last
    end

    def clean_fields fields
      fields.is_a?(Array) ? fields.map{|f| f == "NA" ? "" : f } : fields
    end

    def index_line line
      @index[ line.key ] = line
    end

    def find_mutation line
      @index[ line.key ]
    end

    def required
      self.class.required
    end

    def enforce_headers array
      raise "File lacks required headers: #{(required.map(&:downcase)-array.map(&:downcase)).join(", ")}" if !(required.map(&:downcase) - array.map(&:downcase)).empty?
      @headers = array
    end

    def initialize(mutation_config=nil,suppress_headers=nil)
      @lines = []

      @mutation_config = YAML.load_file(mutation_config) if mutation_config

      @headers = required.map(&:to_sym) unless suppress_headers

      @preamble_lines = []

      @index = {}
    end

    def whitelist file
      case file
      when /.gtf$/
        require 'gtf'
        @whitelist ||= GTF.new(file).to_interval_list
      when /.vcf$/
        require 'vcf'
        @whitelist ||= VCF.read(file).to_interval_list
      end
      @whitelist
    end

    def blacklist file
      case file
      when /.gtf$/
        require 'gtf'
        @blacklist ||= GTF.new(file).to_interval_list
      when /.vcf$/
        require 'vcf'
        @blacklist ||= VCF.read(file).to_interval_list
      end
      @blacklist
    end

    def to_interval_list
      IntervalList.new self.map{|g| [ g.chrom, g.start, g.stop, g ] }
    end

    def inspect
      to_s
    end

    def [](key)
      @lines[key]
    end

    def sort_by! &block
      @lines.sort_by! &block
    end

    def each
      @lines.each do |l|
        yield l
      end
    end

    protected
    def post_read_hook
    end
  end
end
