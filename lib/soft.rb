class Sample
  attribute :type, required: true, pattern: /^SRA$/
  attribute :title, required: true, pattern: /^.{120}$/       #[biomaterial]-[condition(s)]-[replicate number]
  attribute :supplementary_file_NNN, required: true, multiple: true, desc: "Name of supplementary file"
  attribute :supplementary_file_checksum_NNN, multiple: true, pattern: /^\h+$/, desc: "MD5 checksum of file, or name of the MD5 file."
  attribute :supplementary_file_build_NNN, multiple: true, desc: "UCSC or NCBI genome build number (e.g., hg18, mm9, human build 36, etc...). Required when submitting data files which include chromosome position information (e.g., BED, WIG, GFF, etc...)."
  attribute :raw_file_NNN, multiple: true, required: true, desc: "name of raw data file"
  attribute :raw_file_type_NNN, multiple: true, required: true, desc: "Accepted file types are listed in the main high-throughput sequence data submission page."
  attribute :raw_file_checksum_NNN, multiple: true, desc: "MD5 checksum of the raw file, or name of the MD5 file."
  attribute :source_name, required: true, desc: "Briefly identify the biological material and the experimental variable(s), e.g., vastus lateralis muscle, exercised, 60 min."
  attribute :organism, required: true, desc: "Identify the organism(s) from which the biological material was derived."
  attribute :characteristics, required: true, multiple: true, /^\w+: .*$/, desc: "Describe all available characteristics of the biological source, including factors not necessarily under investigation. Provide in 'Tag: Value' format, where 'Tag' is a type of characteristic (e.g. 'gender', 'strain', 'tissue', 'developmental stage', 'tumor stage', etc), and 'Value' is the value for each tag (e.g. 'female', '129SV', 'brain', 'embryo', etc). Include as many characteristics fields as necessary to thoroughly describe your Samples."
  attribute :biomaterial_provider, multiple: true, desc: "Specify the name of the company, laboratory or person that provided the biological material."
  attribute :treatment_protocol, multiple: true, desc: "Describe any treatments applied to the biological material prior to extract preparation. You can include as much text as you need to thoroughly describe the protocol; it is strongly recommended that complete protocol descriptions are provided within your submission."
  attribute :growth_protocol, multiple: true, desc: "Describe the conditions that were used to grow or maintain organisms or cells prior to extract preparation. You can include as much text as you need to thoroughly describe the protocol; it is strongly recommended that complete protocol descriptions are provided within your submission."
  attribute :molecule, required: true, 
    pattern: [ 'total RNA', 'polyA RNA', 'cytoplasmic RNA', 'nuclear RNA', 'genomic DNA', 'protein', 'other' ],
    desc: "Specify the type of molecule that was extracted from the biological material."
  attribute :extract_protocol, required: true, multiple: true, desc: "Describe the protocol used to isolate the extract material. Describe the library construction protocol, ie, the protocols used to extract and prepare the material to be sequenced. You can include as much text as you need to thoroughly describe the protocol; it is strongly recommended that complete protocol descriptions are provided within your submission."
  attribute :library_strategy, required: true, multiple: true, pattern: //,
    desc: "Sequencing technique for this library."
  attribute :library_source, required: true, multiple: true, pattern: [ 'TRANSCRIPTOMIC', 'GENOMIC', 'OTHER '], desc: "Type of source material that is being sequenced."
  attribute :library_selection, required: true, multiple: true, pattern: [],
    desc: "Describes whether any method was used to select and/or enrich the material being sequenced."
  attribute :instrument_model, required: true, multiple: true, pattern: [ 'Illumina Genome Analyzer',
    'Illumina Genome Analyzer', 'Illumina Genome Analyzer II', 'Illumina Genome Analyzer IIx',
    'Illumina HiSeq 2000', 'Illumina HiSeq 1000', 'Illumina MiSeq', 'Illumina HiScanSQ', 
    'AB SOLiD System', 'AB SOLiD System 2.0', 'AB SOLiD System 3.0', 'AB SOLiD 4 System', 
    'AB SOLiD 4hq System', 'AB SOLiD PI System', 'AB SOLiD 5500xl SOLiD System', 'AB SOLiD 5500 SOLiD System', 
    '454 GS', '454 GS 20', '454 GS FLX', '454 GS Junior', '454 GS FLX Titanium', 'Helicos HeliScope',
    'PacBio RS', 'Complete Genomics', 'Ion Torrent PGM' ]
  attribute :data_processing, required: true, desc: "Provide details of how data were generated and calculated. For example, what software was used, how and to what were the reads aligned, what filtering parameters were applied, how were peaks calculated, etc. Include a separate 'data processing' attribute for each file type described."
  attribute :barcode, desc: "For multiplexed/barcode experiments, provide the barcode and/or adapter sequences necessary to interpret the raw data files."
  attribute :description, multiple: true, desc: "Include any additional information not provided in the other fields, or paste in broad descriptions that cannot be easily dissected into the other fields."
  attribute :geo_accession, pattern: /^GSM/, desc: "Only use for performing updates to existing GEO records."
  attribute :table, desc: "Tab-delimited table file name"
end

class Series
  attribute :title, required: true, pattern: /^.{255}$/, desc: "Provide a unique title that describes the overall study."
  attribute :summary, required: true, multiple: true, desc: "Summarize the goals and objectives of this study. The abstract from the associated publication may be suitable. You can include as much text as you need to thoroughly describe the study."
  attribute :overall_design, required: true, desc: "Provide a description of the experimental design. Indicate how many Samples are analyzed, if replicates are included, are there control and/or reference Samples, dye-swaps, etc."
  attribute :pubmed_id, multiple: true, pattern: /^\d+$/, desc: "Specify a valid PubMed identifier (PMID) that references a published article describing this study. Most commonly, this information is not available at the time of submission - it can be added later once the data are published."
  attribute :web_link, multiple: true, pattern: /^http:/, desc: "Specify a Web link that directs users to supplementary information about the study. Please restrict to Web sites that you know are stable."
  attribute :contributor, multiple: true, pattern: /^[\w\-]+,(?:?,)[\w\- ]+$/, desc: "List all people associated with this study."
  attribute :variable_NNN, multiple: true, pattern: [ 'dose', 'time', 'tissue',
    'strain', 'gender', 'cell line', 'development stage', 'age', 'agent', 'cell type',
    'infection', 'isolate', 'metabolism', 'shock', 'stress', 'temperature', 'specimen', 'disease state', 'protocol',
    'growth protocol', 'genotype/variation', 'species', 'individual', 'other' ],
    desc: "Indicate the variable type(s) investigated in this study, e.g., !Series_variable_1 = age !Series_variable_2 = age NOTE - this information is optional and does not appear in Series records or downloads, but will be used to assemble corresponding GEO DataSet records."
  attribute :variable_description_NNN, multiple: true, desc: "Describe each variable, e.g., !Series_variable_description_1 = 2 months !Series_variable_description_2 = 12 months NOTE - this information is optional and does not appear in Series records or downloads, but will be used to assemble corresponding GEO DataSet records."
  attribute :variable_sample_list_NNN, multiple: true, desc: "List which Samples belong to each group, e.g., !Series_variable_sample_list_1 = samA, samB !Series_variable_sample_list_2 = samC, samD NOTE - this information is optional and does not appear in Series records or downloads, but will be used to assemble corresponding GEO DataSet records."
  attribute :repeats_NNN, multiple: true, pattern: [ 'biological replicate', 'technical replicate - extract', 'technical replicate - labeled-extract' ], desc: "Indicate the repeat type(s), e.g., !Series_repeats_1 = biological replicate !Series_repeats_2 = biological replicate NOTE - this information is optional and does not appear in Series records or downloads, but will be used to assemble corresponding GEO DataSet records."
  attribute :repeats_sample_list_NNN, multiple: true, desc: "List which Samples belong to each group, e.g., !Series_repeats_sample_list_1 = samA, samB !Series_repeats_sample_list_2 = samC, samD NOTE - this information is optional and does not appear in Series records or downloads, but will be used to assemble corresponding GEO DataSet records."
  attribute :sample_id, required: true, multiple: true, desc: "Reference the Samples that make up this experiment. Reference the Sample accession numbers (GSMxxx) if the Samples already exists in GEO, or reference the ^Sample identifiers if they are being submitted in the same file."
  attribute :geo_accession, pattern: /^GSE/, desc: "Only use for performing updates to existing GEO records."
end


class Soft
  class Entity
    include Printer
    def initialize
      @line = {}
    end

    def add_attribute line
     set_attribute *get_value_pair(line)
    end

    def get_value_pair line
      line.match(/(.*)=(.*)/) do |m|
        return [ m[1].strip, m[2].strip ]
      end
    end

    def output f
      f.puts indicator_line
    end
  end
  class Platform < Entity
  end
  class Sample < Entity
  end
  class Series < Entity
  end
  def initialize file
    @io = File.open file
    @entities = []
    parse_file
  end

  private
  ENTITY_INDICATOR = /^\^(.*)/
  ENTITY_ATTRIBUTE = /^\!(.*)/
  DATA_HEADER = /^\#(.*)/
  def parse_file file
    while line = @io.gets
      case line.chomp
      when ENTITY_INDICATOR
        parse_indicator Regexp.last_match[1]
      when ENTITY_ATTRIBUTE
        parse_attribute Regexp.last_match[1]
      when DATA_HEADER
        parse_header Regexp.last_match[1]
      else
        parse_data Regexp.last_match[1]
      end
    end
  end

  def parse_indicator line
    @entities.push @current_entity if @current_entity
    @current_entity = create_entity line.to_sym
  end

  def create_entity line
    case line
    when :PLATFORM
      Platform.new
    when :SAMPLE
      Sample.new
    when :SERIES
      Series.new
    end
  end

  def parse_attribute line
    @entity.add_attribute(line)
  end

  def parse_header line
  end

  def parse_data line
  end
end
