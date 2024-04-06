class Settings
  FILENAME = "settings.yml"

  include Singleton

  attr_accessor :values

  def initialize
    if File.exists?(FILENAME)
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
    puts("set values #{values.inspect}")
    @values ||= {}
    @values.merge!(values)
    puts "values in settings: #{@values.inspect}"
    save
  end

  def save
    puts("dumping values #{values}")
    File.write(FILENAME, YAML.dump(values))
  end
end
