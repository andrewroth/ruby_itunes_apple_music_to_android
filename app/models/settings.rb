class Settings
  include Logs

  FILENAME = "settings.yml"

  include Singleton

  attr_accessor :values

  def initialize
    if File.exist?(FILENAME)
      @values = YAML.load(File.read(FILENAME)) 
      puts("loaded values as #{@values}")
    else
      @values = {
        library_path: "Library.xml",
        ftp_username: "pc"
      }
    end
  end

  def values=(values)
    log("set values #{values.inspect}")
    @values ||= {}
    @values.merge!(values)
    log("values in settings: #{@values.inspect}")
    save
  end

  def save
    log("dumping values #{values}")
    File.write(FILENAME, YAML.dump(values))
  end
end
