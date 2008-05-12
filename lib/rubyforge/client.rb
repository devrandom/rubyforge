require 'forwardable'
require 'delegate'
require 'webrick/cookie'
require 'net/http'
require 'net/https'
require 'rubyforge/cookie_manager'

class RubyForge
  class Client
    extend Forwardable
    attr_accessor :debug_dev, :ssl_verify_mode

    def initialize(proxy = nil)
      @debug_dev        = nil
      @ssl_verify_mode  = OpenSSL::SSL::VERIFY_NONE
      @cookie_manager   = CookieManager.new
    end

    def_delegator :@cookie_manager, :save!, :save_cookie_store
    def cookie_store=(path)
      @cookie_manager = CookieManager.load(path)
    end

    def post_content(uri, form = {}, headers = {})
      uri = URI.parse(uri) unless uri.is_a?(URI)
      request = Net::HTTP::Post.new(uri.request_uri)
      execute(request, uri, form, headers)
    end

    def get_content(uri, query = {}, headers = {})
      uri = URI.parse(uri) unless uri.is_a?(URI)
      request = Net::HTTP::Get.new(uri.request_uri)
      execute(request, uri, query, headers)
    end

    private
    def execute(request, uri, parameters = {}, headers = {})
      {
        'content-type' => 'application/x-www-form-urlencoded'
      }.merge(headers).each { |k,v| request[k] = v }

      @cookie_manager[uri].each { |k,v|
        request['Cookie'] = v.to_s
      }

      http = Net::HTTP.new( uri.host, uri.port )
      if uri.scheme == 'https'
        http.use_ssl      = true
        http.verify_mode  = OpenSSL::SSL::VERIFY_NONE
      end

      request_data = case request['Content-Type']
                     when /boundary=(.*)$/
                       boundary_data_for($1, parameters)
                     else
                       query_string_for(parameters)
                     end
      request['Content-Length'] = request_data.length

      response = http.request(request, request_data)
      (response.get_fields('Set-Cookie')||[]).each do |raw_cookie|
        # Super hack to deal with RF's two digit years
        raw_cookie.gsub!(/(\s[0-9]{2}-\w+-)([0-9]{2}\s)/,
          "\\1#{Time.now.year / 100}\\2")
        WEBrick::Cookie.parse_set_cookies(raw_cookie).each { |baked_cookie|
          baked_cookie.domain ||= url.host
          baked_cookie.path   ||= url.path
          @cookie_manager.add(uri, baked_cookie)
        }
      end

      return response.body if response.class <= Net::HTTPSuccess

      if response.class <= Net::HTTPRedirection
        location = response['Location']
        unless location =~ /^http/
          location = "#{uri.scheme}://#{uri.host}#{location}"
        end
        uri = URI.parse(location)

        execute(Net::HTTP::Get.new(uri.request_uri), uri)
      end
    end

    def boundary_data_for(boundary, parameters)
      parameters.map { |k,v|
        parameter = "--#{boundary}\r\nContent-Disposition: form-data; name=\"" +
            WEBrick::HTTPUtils.escape_form(k.to_s) + "\""

        if v.respond_to?(:path)
          parameter += "; filename=\"#{File.basename(v.path)}\"\r\n"
          parameter += "Content-Transfer-Encoding: binary\r\n"
          parameter += "Content-Type: text/plain"
        end
        parameter += "\r\n\r\n"

        if v.respond_to?(:path)
          parameter += v.read
        else
          parameter += WEBrick::HTTPUtils.escape_form(v.to_s)
        end

        parameter
      }.join("\r\n") + "\r\n--#{boundary}--\r\n"
    end

    def query_string_for(parameters)
      parameters.map { |k,v|
        k && [  WEBrick::HTTPUtils.escape_form(k.to_s),
                WEBrick::HTTPUtils.escape_form(v.to_s) ].join('=')
      }.compact.join('&')
    end
  end
end
