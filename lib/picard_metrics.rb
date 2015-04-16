class PicardMetrics
  def initialize
    @sections = []
  end

  def parse file
    File.open(file) do |f|
      until f.eof? do
        section = read_section(f)
        @sections.push section if section
      end
    end
  end

  def read_section f
    header = get_header(f)
    return nil unless header
    section = PicardMetrics.const_get(header.section_type).new
    section.parse f
  end

  class StringHeader
    attr_reader :string
    def parse f
      @string = f.gets.chomp.sub(/^# /,'')
    end
  end

  class RnaSeqMetrics < HashTable
    def parse f

      
    end
  end

  HEADER_PATTERN = /^## (?<string>.*)/
  def get_header f
    line = f.gets
    return nil unless line
    line.chomp!
    return nil unless line.size > 0
    puts line
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
      when "METRICS_CLASS"
        @subtype.split(/\./).last.to_sym
      when "HISTOGRAM"
        :Histogram
      else
        :Noop
      end
    end
  end
end
