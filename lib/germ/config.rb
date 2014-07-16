require 'yaml'
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
end
