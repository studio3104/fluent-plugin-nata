class Fluent::NataOutput < Fluent::Output
  Fluent::Plugin.register_output('nata', self)

  def initialize
    super
    require 'net/http'
    require 'uri'
  end

  config_param :hostname, :string
  config_param :base_url, :string

  def emit(tag, es, chain)
    chain.next
    es.each do |time, record|
      validated_record = validate_record_to_post(time, record)
      if validated_record
        post(validated_record)
      else
        $log.warn "can't post record that is invalid: #{record}"
      end
    end
  end

  SUPPRESS_STRINGS_PATTERN = /(^use \w+;|SET timestamp=\d+;|;$)/
  def validate_record_to_post(time, record)
    unless record[:db]
      $log.warn 'no DATABASE in record'
      return false
    end

    if record[:sql]
      record[:sql] = record[:sql].gsub(SUPPRESS_STRINGS_PATTERN, '')
      record[:sql] = record[:sql].strip
    else
      $log.warn "no SQL in record: #{record[:db]}"
      return false
    end

    record[:date] = Time.at(time) unless record[:date]
    record
  end

  def post(record)
    begin
      api = URI.parse(@base_url + "/api/1/add/slow_log/#{@hostname}/#{record[:db]}")
      request = Net::HTTP::Post.new(api.path)
      request.set_form_data(record)
      http = Net::HTTP.new(api.host, api.port)
      response = http.start.request(request)
    rescue IOError, EOFError, SystemCallError => e
      $log.warn "net/http POST raises exception: #{e.class}, '#{e.message}'"
    end
    if !response || !response.is_a?(Net::HTTPSuccess)
      $log.warn "failed to post to nata: #{api}, sql: #{record[:sql]}, code: #{response && response.code}"
    end
  end
end
