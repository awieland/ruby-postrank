require 'CGI'
require 'json'
require 'net/http'
require 'uri'

module PostRank
  class Server
    attr_accessor :app_key, :server, :port

    @@api_version = 'v1'

    def initialize(app_key, opts={})
      raise Exception, "Application name is invalid" if app_key.nil? ||
                                                       !app_key.is_a?(String) ||
                                                        app_key.empty?

      self.app_key = app_key
      self.server = opts[:server] || 'api.postrank.com'
      self.port = opts[:port] || 80
    end

    def server=(server)
      raise Exception, "Invalid server URL" if !valid_url(server)
      @server = server
    end

    def port=(port)
      raise Exception, "Invalid port" if !port.is_a?(Fixnum) || port < 0 || port > 65535
      @port = port
    end

    def feed(url, priority=85)
      raise Exception, "Invalid url" if !valid_url(url)
      d = JSON.parse(get(Method::FEED_ID, Format::JSON, [['priority', priority], ['url', url]]))
      raise Exception, d['error'] if d.has_key?('error')
      Feed.new(self, d['feed_id'], d['url'], d['link'])
    end

    def post_rank(urls=[], feeds=[])
      return [] if urls.empty?

      params = []
      urls.each { |url| params << ['url[]', url] }
      feeds.each { |feed| ['feed[]', feed] }

      d = JSON.parse(post(Method::POST_RANK, Format::JSON, params))
      raise Exception, d['error'] if d.has_key?('error')

      ret = []
      urls.each do |url|
        data = d[url]

        e = Entry.new
        e.link = url
        e.post_rank = data['postrank']
        e.post_rank_color = data['postrank_color']

        ret << e
      end

      ret
    end

    # The params array is an array of arrays. Each internal array is the
    # key=value pair that will be passed to the request
    def get(method, format, params=[])
      Net::HTTP.get(URI.parse("http://#{@server}:#{@port}" + base_url(method, format) + join_params(params)))
    end

    def post(method, format, params=[])
      Net::HTTP.new(@server, @port).post(base_url(method, format), join_params(params)).body
    end

    def self.api_version
      @@api_version
    end

    private
    # Regex from: http://www.igvita.com/2006/09/07/validating-url-in-ruby-on-rails/
    def valid_url(url)
      url =~ /^((http|https):\/\/)?[a-zA-Z0-9]+([\-\.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,5}(([0-9]{1,5})?\/.*)?$/ix
    end

    def base_url(method, format)
      "/#{Server.api_version}/#{method}?format=#{format}&appkey=#{self.app_key}&"
    end

    def join_params(params)
      params.collect{ |p| p.collect { |e| e.to_s }.join('=') }.join('&')
    end
  end
end
