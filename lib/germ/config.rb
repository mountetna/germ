require 'yaml'
class TaylorlibConfig
  def self.get_conf *keys
    config = TaylorlibConfig.new
    config.get_key *keys if config.loaded?
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
    ENV["TAYLORLIB_CONF"]
  end

  def file_exists?
    config_file && File.exists?(config_file)
  end

  def load_file
    @config = YAML.load File.read(config_file)
  end
end
