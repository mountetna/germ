require 'hash_table'
require 'extlib'

class PicardMetrics
  attr_reader :sections
  def initialize
    @sections = {}
  end

  def parse file
    File.open(file) do |f|
      until f.eof? do
        section = read_section(f)
        @sections[section.name] = section if section
      end
    end

    self
  end

  def read_section f
    header = get_header(f)
    return nil unless header
    section = PicardMetrics.const_get(header.section_type).new
    section.parse f
    section
  end

  class Metric
    def name
      self.class.name.split(/::/).last.snake_case.to_sym
    end
  end

  class Noop < Metric
    def parse f
    end
  end

  class StringHeader < Metric
    attr_reader :string
    def parse f
      @string = f.gets.chomp.sub(/^# /,'')
    end
  end

  class Histogram < Metric
    attr_reader :values
    def parse f
      header = f.gets
      @values = []
      while (line = f.gets) && line.chomp.size > 0
        pos, cov = line.chomp.split(/\t/)
        @values.push [ pos.to_i, cov.to_f ]
      end
    end
  end

  class RnaSeqMetrics < Metric
    attr_reader :metrics
    def parse f
      keys = f.gets.chomp.split(/\t/).map(&:downcase).map(&:to_sym)
      values = f.gets.chomp.split(/\t/).map &:to_f
      @metrics = Hash[keys.zip values]
    end

    def respond_to_missing? sym, flag = true
      return true if @metrics.has_key? sym
    end

    def method_missing sym, *args, &block
      if @metrics.has_key? sym
        @metrics[sym]
      else
        super
      end
    end
  end

  HEADER_PATTERN = /^## (?<string>.*)/
  def get_header f
    line = f.gets
    return nil unless line
    line.chomp!
    return nil unless line.size > 0
    Header.new line.match(HEADER_PATTERN)[:string]
  end

  class Header
    attr_reader :type, :subtype
    def initialize head
      @type, @subtype = head.split(/\t/,2)
    end

    def section_type
      case @type
      when "net.sf.picard.metrics.StringHeader"
        :StringHeader
      when "METRICS CLASS"
        @subtype.split(/\./).last.to_sym
      when "HISTOGRAM"
        :Histogram
      else
        :Noop
      end
    end
  end
end
