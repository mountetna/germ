require 'net/http/persistent'
require 'resolv-replace'
require 'json'
require 'sequel'
require 'yaml'
require 'germ/config'

class Oncotator
  attr_accessor :mutation
  def self.persistent_connection
    @http ||= Net::HTTP::Persistent.new
  end

  def self.db_connect opts
    @db_opts = opts
  end

  def self.db_opts
    @db_opts ||= TaylorlibConfig.get_conf :oncotator
  end

  def self.db_cache
    @db ||= Sequel.connect(db_opts)
    @db[:onco_json_cache]
  end

  def self.insert_onco onco
    if defined? Rails
      OncoJsonCache.create onco
    else
      db_cache.insert_ignore.insert onco
    end
  end

  def self.db_obj
    if defined? Rails
      OncoJsonCache
    else
      Oncotator.db_cache
    end
  end

  def self.find_key cache_key
    # use the Rails environment if it is available
    db_obj.where(:CACHE_KEY => cache_key).first
  end

  def self.delete_key cache_key
    db_obj.where(:CACHE_KEY => cache_key).delete
  end

  def onco_uri
    URI "http://69.173.64.101/oncotator/mutation/#{@mutation}/"
  end

  def get_json_object text=nil
    # first look it up in the sequel database.
    json = case text
    when nil
      result = Oncotator.find_key @mutation
      result ? result[:RAW_JSON] : nil
    else
      text
    end
    
    begin
      return JSON.parse(json) if json
    rescue JSON::ParserError => e
      # you have a bad data blob
      Oncotator.delete_key @mutation
    end

    # if that doesn't work, query Oncotator.
    response = Oncotator.persistent_connection.request(onco_uri)

    return {} if response.code != "200"
    
    json = response.body

    # save it
    Oncotator.insert_onco(:CACHE_KEY => @mutation, :RAW_JSON => json)

    return JSON.parse(json)
  end

  def initialize(opts)
    if opts[:key]
      @mutation = opts[:key]
      @onco = get_json_object
    elsif opts[:text]
      @onco = get_json_object opts[:text]
    end
  end

  def empty?
    !@onco || @onco.size == 0
  end

  class Transcript
    def initialize(txp)
      @txp = txp || {}
    end

    def method_missing(meth,*args,&block)
      @txp[meth.to_s] || nil
    end
  end

  def best_effect_txp
    @best_effect_txp ||= Transcript.new(transcripts[best_effect_transcript]) if best_effect_transcript
  end

  def best_canonical_txp
    @best_canonical_txp ||= Transcript.new(transcripts[best_canonical_transcript]) if best_canonical_transcript
  end

  def is_snp
    dbSNP_RS && dbSNP_Val_Status =~ /(byFrequency|by1000genomes)/
  end

  def txp
    best_effect_txp
  end

  def pph2_class
    pph2 ? pph2["pph2_class"] : nil
  end

  def is_cancerous
    self.Cosmic_overlapping_mutations || self.CGC_Tumor_Types_Somatic || self.CCLE_ONCOMAP_total_mutations_in_gene
  end

  def method_missing(meth,*args,&block)
    meth = meth.to_s
    case 
    when @onco[meth]
      @onco[meth]
    when meth =~ /^txp_(.*)/
      txp ? txp.send($1) : nil
    else
      nil
    end
  end
end
