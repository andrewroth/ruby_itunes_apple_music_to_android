class Log
  include Singleton

  def log(line)
    STDOUT.puts("[#{Time.now}] #{line}")
  end
end
