require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'fluent/test'
unless ENV.has_key?('VERBOSE')
  nulllogger = Object.new
  nulllogger.instance_eval {|obj|
    def method_missing(method, *args)
      # pass
    end
  }
  $log = nulllogger
end

require 'fluent/plugin/out_nata'
require 'myslog'

class Test::Unit::TestCase
end

# defines a method for converting a string hash keys.
# because MySlog returns symbolized hash.
class Hash
  def stringify_keys
    inject({}) do |options, (key, value)|
      value = value.stringify_keys if defined?(value.stringify_keys)
      options[(key.to_s rescue key) || key] = value
      options
    end
  end
end

require 'webrick'

__END__
# to handle POST/PUT/DELETE ...
module WEBrick::HTTPServlet
  class ProcHandler < AbstractServlet
    alias do_POST   do_GET
    alias do_PUT    do_GET
    alias do_DELETE do_GET
  end
end

def get_code(server, port, path, headers={})
  require 'net/http' 
  Net::HTTP.start(server, port){|http|
    http.get(path, headers).code
  } 
end 
def get_content(server, port, path, headers={})
  require 'net/http'
  Net::HTTP.start(server, port){|http|
    http.get(path, headers).body
  } 
end

