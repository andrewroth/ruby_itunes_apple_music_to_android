class Log
  include Singleton

  def initialize
    @file = File.open("out.log", "w")
    @history = "".force_encoding("utf-8")
  end

  def log(line)
    #STDOUT.puts("[#{Time.now}] #{line}")
    @history += "#{line}\n".force_encoding("utf-8")
    @file.puts("[#{Time.now}] #{line}")
  end
end
