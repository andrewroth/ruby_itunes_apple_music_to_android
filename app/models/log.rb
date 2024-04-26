class Log
  include Singleton

  def initialize
    @file = File.open("out.log", "w")
    @history = "".force_encoding("utf-8")
    @log_text_ready = false
    @i = 0

    # tk leaves something to be desired... best way I could find to see when tab changes
    Thread.new {
      MainUi.instance.notebook.bind("Button-1", proc{|k| Log.instance.trigger_log })
      MainUi.instance.notebook.bind("Button-2", proc{|k| Log.instance.trigger_log })
      MainUi.instance.notebook.bind("Button-3", proc{|k| Log.instance.trigger_log })
    }
  end

  def trigger_log
    Thread.new {
      sleep 0.2
      log(nil)
      sleep 1
      log(nil)
    }
  end

  def log(line)

    if line
      line = "[#{Time.now}] #{line}"
      @file.puts(line)
    end

    # only populate the log_text field when the tab is opened to save cpu/memory
    if MainUi.instance.log_text && MainUi.instance.log_tab_selected
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
        @history.split("\n").each_with_index do |line, i|
          add_log_text_line(line)
          # UI hangs withoutthis
          if i % 100 == 0
            sleep 1
          else
            sleep 0.1
          end
        end
        @history = "".force_encoding("utf-8")

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
    return if line.nil? || line == ""

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
