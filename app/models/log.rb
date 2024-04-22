class Log
  include Singleton

  def initialize
    @file = File.open("out.log", "w")
    @history = ""
  end

  def log(line)
    #STDOUT.puts("[#{Time.now}] #{line}")
    @history += "#{line}\n"
    @file.puts("[#{Time.now}] #{line}")
  end
end
