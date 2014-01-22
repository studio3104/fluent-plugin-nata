require 'helper'

class NataOutputTest < Test::Unit::TestCase
  NATA_TEST_HOST = '127.0.0.1'
  NATA_TEST_PORT = '11180'

  CONFIG = %[
    hostname test_host
    base_url http://#{NATA_TEST_HOST}:#{NATA_TEST_PORT}
  ]

  SLOW_LOG = %[
# Time: 131031 12:39:55
# User@Host: root[root] @ localhost []  Id:     4
# Query_time: 10.001142  Lock_time: 0.000000 Rows_sent: 1  Rows_examined: 0
use test;
SET timestamp=1383190795;
select sleep(10);
# Time: 131031 12:38:58
# User@Host: root[root] @ localhost []  Id:     3
# Query_time: 10.001110  Lock_time: 0.000000 Rows_sent: 1  Rows_examined: 0
use information_schema;
SET timestamp=1383190738;
select sleep(10);
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::NataOutput, tag).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal "http://#{NATA_TEST_HOST}:#{NATA_TEST_PORT}", d.instance.base_url
    assert_equal 'test_host', d.instance.hostname
  end

  def test_post
    d = create_driver
    @slowlog_parser.parse(SLOW_LOG.strip).each do |parsed_slow|
      d.emit(parsed_slow)
    end
    d.run

    assert_equal 2, @posted.size
  end

  def setup
    Fluent::Test.setup
    @slowlog_parser = MySlog.new
    @posted = []
    @dummy_server_thread = Thread.new do
      srv = if ENV['VERBOSE']
              WEBrick::HTTPServer.new({ BindAddress: NATA_TEST_HOST, Port: NATA_TEST_PORT })
            else
              logger = WEBrick::Log.new('/dev/null', WEBrick::BasicLog::DEBUG)
              WEBrick::HTTPServer.new({ BindAddress: NATA_TEST_HOST, Port: NATA_TEST_PORT, Logger: logger, AccessLog: [] })
            end
      begin
        srv.mount_proc('/api/1/add/slow_log') do |request, response| # /api/1/add/slow_log/:host/:db
          unless request.request_method == 'POST'
            response.status = 405
            response.body = 'request method mismatch'
            next
          end

          next unless request.path
          request_path = request.path.match(Regexp.new('^/api/1/add/slow_log/([^/]+)/(.+)$'))
          host = request_path[1]
          db = request_path[2]

          @posted.push(
            host: host,
            db: db,
            data: request.body
          )

          response.status = 200
        end

        srv.mount_proc('/') do |request, response|
          response.status = 200
          response.body = 'running'
        end

        srv.start
      ensure
        srv.shutdown
      end
    end

    # to wait completion of dummy server.start()
    require 'thread'
    cv = ConditionVariable.new
    Thread.new {
      connected = false
      while not connected
        begin
          path = '/'
          headers = {}
          Net::HTTP.start(NATA_TEST_HOST, NATA_TEST_PORT) do |http|
            http.get(path, headers).body
          end
          connected = true
        rescue Errno::ECONNREFUSED
          sleep 0.1
        rescue StandardError => e
          p e
          sleep 0.1
        end
      end
      cv.signal
    }
    mutex = Mutex.new
    mutex.synchronize {
      cv.wait(mutex)
    }
  end

  def teardown
    @dummy_server_thread.kill
    @dummy_server_thread.join
  end
end
