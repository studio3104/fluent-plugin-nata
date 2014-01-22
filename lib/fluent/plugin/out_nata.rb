class Fluent::NataOutput < Fluent::Output
  Fluent::Plugin.register_output('nata', self)

  def initialize
    super
    require 'net/http'
    require 'uri'
  end

  config_param :host, :string
  config_param :db, :string
  config_param :base_url, :string

  def emit(tag, es, chain)
    chain.next
    es.each do |time, record|
      prepared_record = prepare_record_to_post(time, record)
      post(prepared_record)
    end
  end

  SUPPRESS_STRINGS_PATTERN = /(^use \w+;|SET timestamp=\d+;|;$)/
  def prepare_record_to_post(time, record)
    prepared_record = record
    prepared_record[:date] = Time.at(time) unless prepared_record[:date]

    if prepared_record[:sql]
      prepared_record[:sql] = prepared_record[:sql].sub(SUPPRESS_STRINGS_PATTERN, '')
      prepared_record[:sql] = prepared_record[:sql].strip
    else
      $log.warn "no SQL in record: #{api}"
    end

    prepared_record
  end

  def post(record)
    begin
      api = URI.parse(@base_url + "/api/1/add/slow_log/#{@host}/#{@db}")
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
