require 'mutation_set'
require 'oncotator'
require 'yaml'

class VCF < MutationSet::Sample
  requires "#CHROM", "POS", "ID", "REF", "ALT", "QUAL", "FILTER", "INFO", "FORMAT"
  comments "##"

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

  def enforce_headers(array)
    # kludge for empty vcf with no format line
    missing = required.map(&:downcase) - array.map(&:downcase)
    raise "VCF lacks required headers" if !missing.empty? && !(missing.first == "format" && missing.size == 1)

    if array.size > required.size
      @samples = array - required
    end

    @headers = array.map &:to_sym
  end

  class Line < MutationSet::Line
    attr_reader :format, :mutation
    alias_key :start, :pos
    alias_key :ref_allele, :ref
    def alt_allele; pick_alt; end
    def stop; @stop || end_pos; end
    def stop= nc; @stop = nc; end

    def required
      sample.required
    end

    def initialize(fields, s)
      @sample = s
      @mutation = Hash[clean_required.zip(fields[0...required.size])]
      @mutation[:info] = Hash[@mutation[:info].split(/;/).map do |s| 
        key, value = s.split(/=/)
        value ||= true
        [ key.to_sym, value ]
      end]
      @format = @mutation[:format] = @mutation[:format].split(/:/).map(&:to_sym)

      if @sample.samples
        sample_fields = fields[required.size..-1]
        @genotypes = {}
        @sample.samples.each_with_index do |s,i|
          next if !sample_fields[i]
          @genotypes[s] = VCF::Genotype.new self, sample_fields[i].split(/:/)
        end
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

    def end_pos
      pos.to_i + ref.length-1
    end

    def to_s
      clean_required.map{ |h|
        case h
        when :info
        mutation[h].map{|k,v|  "#{k}=#{v}" }.join(";")
        when :format
        mutation[h].join(":")
        else
        mutation[h]
        end
      }.join("\t") + "\t" + sample.samples.map{|s| genotype(s).to_s }.join("\t")
    end

    def genotype(s)
      @genotypes[s] if @genotypes
    end

    def clean_required
      sample.clean_headers[0...required.size]
    end
  end

  class Genotype
    attr_reader :info
    def initialize(line,field)
      @line = line
      @info = Hash[line.format.zip(field)]
    end

    def homozygous?
      @info[:GT] =~ /0.0/ || @info[:GT] =~ /1.1/
    end

    def heterozygous?
      @info[:GT] =~ /0.1/ || @info[:GT] =~ /1.0/
    end

    def empty?
      @info[:GT] =~ /\..\./
    end

    def callable?
      @info[:GT] !~ /\..\./
    end

    def gt; @info[:GT]; end
    def approx_depth; @info[:DP].to_i; end
    def depth; alt_count + ref_count; end
    def alt_count; @info[:AD] ? @info[:AD].split(/,/)[1].to_i : nil; end
    def ref_count; @info[:AD] ? @info[:AD].split(/,/)[0].to_i : nil; end
    def alt_freq; alt_count / depth.to_f; end
    def ref_freq; ref_count / depth.to_f; end
    def ref_length; @line.ref.length; end
    def alt_length; @line.alt.length; end
    def alt_base_quality; @info[:NQSBQ] ? @info[:NQSBQ].split(/,/)[0].to_f : nil; end
    def alt_map_quality; @info[:MQS] ? @info[:MQS].split(/,/)[0].to_f : nil; end
    def alt_mismatch_rate; @info[:NQSMM] ? @info[:NQSMM].split(/,/)[0].to_f : nil; end
    def alt_mismatch_count; @info[:MM] ? @info[:MM].split(/,/)[0].to_f : nil; end
    def quality; @info[:GQ].to_i; end

    def to_s
      @line.format.map{|f| @info[f]}.join(":")
    end
  end
end
