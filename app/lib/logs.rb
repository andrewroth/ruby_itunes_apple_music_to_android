module Logs
  def log(s)
    Log.instance.log("[#{self.class.name}##{caller_locations(1,1)[0].label.gsub("block in ", "")}] #{s}")
  end

  def log_trace(e)
    log("#{e.class.name}: #{e.to_s}")
    e.backtrace.each do |caller|
      log(caller)
    end
    Log.instance.flush
  end
end
