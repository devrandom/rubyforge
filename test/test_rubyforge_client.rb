require 'test/unit' unless defined? $ZENTEST and $ZENTEST
require 'rubyforge'

class TestRubyForgeClient < Test::Unit::TestCase
  def setup
    RubyForge::Client.const_set(:Net, Module.new)
    RubyForge::Client::Net.const_set(:HTTP, Class.new(DelegateClass(::Net::HTTP)))

    RubyForge::Client::Net.class_eval do
      def self.const_missing(sym)
        ::Net.const_get(sym)
      end
    end

    RubyForge::Client::Net::HTTP.class_eval do
      def initialize(*args)
        @http = ::Net::HTTP.new(*args)
        super(@http)
      end

      class << self; attr_accessor :t_request, :t_data; end
      def request(request, data)
        self.class.instance_variable_set(:@t_request, request)
        self.class.instance_variable_set(:@t_data, data)
        response = Net::HTTPOK.new('1.1', 200, '')
        class << response
          def read_body; ''; end
        end
        return response
      end

      def self.const_missing(sym)
        ::Net::HTTP.const_get(sym)
      end
    end

    @client = RubyForge::Client.new
  end

  def teardown
    RubyForge::Client.class_eval { remove_const(:Net) }
  end

  def test_post_with_params
    @client.post_content('http://example.com', { :f => 'adsf'})
    assert_equal('f=adsf', RubyForge::Client::Net::HTTP.t_data)

    @client.post_content('http://example.com', { :a => 'b', :c => 'd' })
    assert_equal('a=b&c=d', RubyForge::Client::Net::HTTP.t_data)
  end

  def test_multipart_post_one_param
    random = Array::new(8){ "%2.2d" % rand(42) }.join('__')
    boundary = "multipart/form-data; boundary=___#{ random }___"

    request = <<-END
--___#{random}___\r
Content-Disposition: form-data; name="a"\r\n\r
b\r
--___#{random}___--\r
END

    @client.post_content( 'http://example.com',
                          { :a => 'b' },
                          { 'content-type' => boundary }
                        )
    assert_equal(request, RubyForge::Client::Net::HTTP.t_data)
  end

  def test_multipart_post_two_params
    random = Array::new(8){ "%2.2d" % rand(42) }.join('__')
    boundary = "multipart/form-data; boundary=___#{ random }___"

    request = <<-END
--___#{random}___\r
Content-Disposition: form-data; name="a"\r\n\r
b\r
--___#{random}___\r
Content-Disposition: form-data; name="c"\r\n\r
d\r
--___#{random}___--\r
END

    @client.post_content( 'http://example.com',
                          { :a => 'b', :c => 'd' },
                          { 'content-type' => boundary }
                        )
    assert_equal(request, RubyForge::Client::Net::HTTP.t_data)
  end

  def test_multipart_io
    random = Array::new(8){ "%2.2d" % rand(42) }.join('__')
    boundary = "multipart/form-data; boundary=___#{ random }___"

    file_contents = 'blah blah blah'
    file = StringIO.new(file_contents)
    class << file
      def path
        '/one/two/three.rb'
      end
    end

    request = <<-END
--___#{random}___\r
Content-Disposition: form-data; name="userfile"; filename="three.rb"\r
Content-Transfer-Encoding: binary\r
Content-Type: text/plain\r\n\r
#{file_contents}\r
--___#{random}___--\r
END

    @client.post_content( 'http://example.com',
                          { :userfile => file },
                          { 'content-type' => boundary }
                        )
    assert_equal(request, RubyForge::Client::Net::HTTP.t_data)
  end
end
