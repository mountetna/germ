require 'yaml'
require 'extlib'

class GermConfig
  def self.get_conf *keys
    @config ||= GermConfig.new
    @config.get_key *keys if @config.loaded?
  end

  def initialize
    load_file if file_exists?
  end

  def loaded?
    @config != nil
  end

  def get_key *keys
    keys.inject(@config) do |obj,key|
      raise GermConfig::KeyError, "Broken key chain: #{keys}" unless obj
      obj = obj[key]
    end
  end

  private
  def config_file
    ENV["GERM_CONF"]
  end

  def file_exists?
    config_file && File.exists?(config_file)
  end

  def load_file
    @config = YAML.load File.read(config_file)
  end

  class KeyError < StandardError
  end
end


module GermDefault
  CACHE = {}

  def has_default *key_chain
    @key_chain = key_chain
  end

  def cache
    CACHE[self] ||= {}
  end

  def default
    # get the default key
    cache[:default] ||= load_default
  end


  def cache_load key
    cache[key] ||= load_key(key)
  end

  def method_missing sym, *args, &block
    begin
      cache_load sym
    rescue GermConfig::KeyError
      # the key does not exist, try to pass it on
      super
    end
  end

  protected
  def default_create *args
    new *args
  end

  private
  def key_chain
    @key_chain ||= name.split(/::/).map do |name| name.snake_case.to_sym; end
  end

  def load_default
    key = GermConfig.get_conf *key_chain, :default
    raise GermConfig::KeyError, "No default key defined!" unless key
    cache_load key
  end

  def load_key key
    args = GermConfig.get_conf *key_chain, key
    raise GermConfig::KeyError, "No such key defined!" unless args
    default_create *args
  end
end
