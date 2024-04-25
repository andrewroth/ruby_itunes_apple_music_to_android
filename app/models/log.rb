class Log
  include Singleton

  def initialize
    @file = File.open("out.log", "w")
    @history = "".force_encoding("utf-8")
    @log_text_ready = false
    @i = 0
  end

  def log(line)
    #STDOUT.puts("[#{Time.now}] #{line}")
    line = "[#{Time.now}] #{line}"
    @file.puts(line)

    if MainUi.instance.log_text
      if !@log_text_ready
        date = { foreground: "darkblue" }
        call = { foreground: "darkred" }
        odd = { }
        even = { background: "#EFEFEF" }
        MainUi.instance.log_text.tag_configure("date-odd", date.merge(odd))
        MainUi.instance.log_text.tag_configure("date-even", date.merge(even))
        MainUi.instance.log_text.tag_configure("call-odd", call.merge(odd))
        MainUi.instance.log_text.tag_configure("call-even", call.merge(even))
        MainUi.instance.log_text.tag_configure("odd", odd)
        MainUi.instance.log_text.tag_configure("even", even)
        @history.split("\n").each do |line|
          add_log_text_line(line)
        end

        @log_text_ready = true
      end

      add_log_text_line(line)
      #MainUi.instance.log_text.insert(:end, "\n" + line)
      MainUi.instance.log_text.yview_moveto(1.0)
    else
      @history += "#{line}\n".force_encoding("utf-8")
    end
  end

  def add_log_text_line(line)
    @i += 1
    odd_even = @i % 2 == 0 ? "odd" : "even"

    MainUi.instance.log_text.insert(:end, "\n")

    if line =~ /(\[[^\]]*\]) (\[[^\]]*\]) (.*)/
      time = $1
      call = $2
      line = $3
      MainUi.instance.log_text.insert(:end, time, "date-#{odd_even}")
      MainUi.instance.log_text.insert(:end, " ", odd_even)
      MainUi.instance.log_text.insert(:end, call, "call-#{odd_even}")
      MainUi.instance.log_text.insert(:end, " ", odd_even)
    end

    MainUi.instance.log_text.insert(:end, line, odd_even)
  end
end
