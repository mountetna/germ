require 'hash_table'
require 'germ/config'

module GO
  class TagSet
    def initialize
      @tags = {}
    end

    attr_reader :tags
    def add_tag line
      tag, value = line.scan(/^(.*?): (.*?)(?:!.*)?$/).flatten
      tag = tag.to_sym
      @tags[tag] ||= Set.new
      @tags[tag] << value
    end

    def respond_to_missing? sym, include_all = false
      @tags.has_key?(sym) || super
    end

    def method_missing sym
      set = @tags[sym]
      if set 
        if set.size == 1
          set.first
        else
          set
        end
      else
        super
      end
    end
  end
  class Ontology
    extend GermDefault

    attr_reader :header, :terms
    def initialize file
      @header = TagSet.new
      @terms = {}
      @types = []
      parse_file(file) if File.exists?(file)
    end

    BLANK_LINE = /^\s*$/
    TERM = /^\[Term\]$/
    TYPEDEF = /^\[Typedef\]$/

    def parse_file file
      @io = File.open file
      while line = @io.gets
        line.chomp!
        next if line =~ BLANK_LINE
        if line =~ TERM
          read_term
        elsif line =~ TYPEDEF
          read_typedef
        else
          @header.add_tag line
        end
      end
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @terms=#{@terms.count}>"
    end

    def read_term
      term = read_stanza
      @terms[term.id] = term
    end

    def read_typedef
      @types.push read_stanza
    end

    def read_stanza
      stanza = TagSet.new
      while line = @io.gets
        line.chomp!
        break if line =~ BLANK_LINE
        stanza.add_tag line
      end
      stanza
    end
  end
  class Annotation < HashTable
    extend GermDefault
    def initialize file=nil, opts={}
      opts = opts.merge :header => [ :db, :db_object_id, :db_object_symbol,
                               :qualifier, :go_id, :db_reference,
                               :evidence_code, :with, :aspect, :db_object_name,
                               :synonym, :db_object_type, :taxon, :date,
                               :assigned_by, :annotation_extension,
                               :gene_product_form_id ],
                  :skip_header => true,
                  :comment => "!",
                  :ontology => GO::Ontology.default
      super file, opts
    end
    def ontology
      @ontology ||= @opts[:ontology]
    end
    class AnnotationLine < HashTable::HashLine
      def term
        @table.ontology.terms[go_id]
      end
    end
    line_class AnnotationLine
  end
end
