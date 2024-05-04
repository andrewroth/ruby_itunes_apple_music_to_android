# expects including classes to also include Logs
module HasStatus
  def window_name
    raise("including class should implement this")
  end

  def set_status(status)
    #log("#{window_name} set status: #{status.inspect}")
    #@status_label.configure(text: Tk::UTF8_String.new(status))
    #WebServer.instance.driver.execute_script(%|$("#status").html(""
    WebServer.exec_async(%|$("#status").html("#{WebServer.h(status)}")|)
  end
end
