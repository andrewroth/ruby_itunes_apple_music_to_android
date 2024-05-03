require "rack"
require "thin"
require "selenium-webdriver"

class NotFound
  def call(env)
    content = 'Not Found'
    [404, {'Content-Type' => 'text/html', 'Content-Length' => content.size.to_s}, [content]]
  end
end

class WebServer
  def self.instance
    @instance
  end

  def self.instance=(val)
    @instance = val
  end

  attr_reader :driver

  # these should be moved to somewhere better
  def self.h(val)
    Rack::Utils.escape_html(val)
  end

  def self.exec(val)
    instance.driver.execute_script(val)
  end

  # ####

  def initialize(app, driver)
    @app = app
    @driver = driver
  end

  def call(env)
    req = Rack::Request.new(env)
    puts("WebServer#call #{req.path}, (#{req.params.class}) #{req.params}")

    case req.path
    when "/quit"
      FileUtils.touch("exit_now")
      return [200, { 'Content-Type' => 'text/plain' }, ['Quitting.']]
    when "/message"
=begin
      begin
        data = JSON.parse(req.params)
      rescue Exception => e
        puts "Error"
        return [400, { 'Content-Type' => 'text/plain' }, ["Error parsing JSON: #{e.class.name}: #{e}"]]
      end
=end

      puts("Message #{req.params}")

      response = MainUi.instance.message(req.params)
      #response = "Received"

      #puts("Executing script here")
      #puts("@driver: #{@driver}")
      #@driver.execute_script(%|console.log("message received")|)

      return [200, { 'Content-Type' => 'text/plain' }, [response]]
    else
      if @app
        response = @app.call(env)
      else
        return [200, { 'Content-Type' => 'text/plain' }, []]
      end
    end
  end
end

def start_all
  Thread.new {
    while true do
      if File.exist?("exit_now")
        #Process.kill("INT", Process.pid)
        File.delete("exit_now")
        puts("Exit exit_now detected")
        @driver&.quit
        exit(0)
      end
      sleep 1
    end
  }


  #browser_thread = Thread.new {
  @driver = driver = Selenium::WebDriver.for :firefox
  Thread.new {
    begin
      driver.navigate.to "http://localhost:8080"
    rescue Selenium::WebDriver::Error::UnknownError
      sleep 0.5
      retry
    end
    Thread.new {
      MainUi.instance.start
    }
  }
  #}

  static = Rack::Static.new(NotFound.new, urls: [""], root: "public", index: "index.html")
  WebServer.instance = server = WebServer.new(static, driver)

  t1 = Thread.new {
    server = ::Thin::Server.new("0.0.0.0", "8080", server)
    server.start!
  }

  t1.join
  #browser_thread.join

  begin
    @driver&.quit
  rescue Exception => e
  end
end
