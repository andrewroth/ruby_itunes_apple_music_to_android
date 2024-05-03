require "rack/utils"

class Log
  include Singleton

  def initialize
    @file = File.open("out.log", "w")
    @history = "".force_encoding("utf-8")
    @i = 0
  end

  def log(line)
    return if line.nil? || line == ""

    if line
      line.gsub!("\n", "<br/>")
      line = "#{Thread.current.object_id} [#{Time.now}] #{line}"
      @file.puts(line)
      #puts line
    end

    @i += 1
    odd_even = @i % 2 == 0 ? "odd" : "even"

=begin
    if line =~ /(\[[^\]]*\]) (\[[^\]]*\]) (.*)/
      time = $1
      call = $2
      line = $3
      #MainUi.instance.log_text.insert(:end, time, "date-#{odd_even}")
      #MainUi.instance.log_text.insert(:end, " ", odd_even)
      #MainUi.instance.log_text.insert(:end, call, "call-#{odd_even}")
      #MainUi.instance.log_text.insert(:end, " ", odd_even)
    end
=end

    #cmd = %|$("#log").append("<div>#{Rack::Utils.escape_html(line)}</div>");|
    #puts cmd
    #WebServer.instance.driver.execute_script(%|#{cmd}|)
  end

  def flush
    @file.flush
  end
end
