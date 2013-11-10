require 'helper'
require 'net/http'
require 'uri'
require 'fileutils'

class KibanaServerInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  BIND = '0.0.0.0'
  PORT = 24300
  MOUNT = '/kibana/'
  ACCESS_LOG_PATH = File.join(File.dirname(__FILE__), 'access.log')

  ELASTICSEARCH_URL = 'http://localhost:9200'


  def create_driver(conf)
    Fluent::Test::InputTestDriver.new(Fluent::KibanaServerInput).configure(conf)
  end

  def test_configure
    d = create_driver(create_config)

    assert_equal BIND, d.instance.bind
    assert_equal PORT, d.instance.port
    assert_equal MOUNT, d.instance.mount
    assert_equal ACCESS_LOG_PATH, d.instance.access_log_path
    assert_equal ELASTICSEARCH_URL, d.instance.elasticsearch_url
  end

  def test_listen
    d = create_driver(create_config(bind:'localhost'))

    d.run do
      res = Net::HTTP.get_response(URI.parse("http://localhost:#{PORT}#{MOUNT}"))
      assert_equal Net::HTTPOK, res.class
    end

    FileUtils.rm_f ACCESS_LOG_PATH
  end

  def test_access_log
    d = create_driver(create_config(bind:'localhost'))
    d.run
    assert_equal true, File.file?(ACCESS_LOG_PATH)
    FileUtils.rm_f ACCESS_LOG_PATH
  end

  private

  def create_config(opts={})
    merged = {
      bind: BIND,
      port: PORT,
      mount: MOUNT,
      access_log_path: ACCESS_LOG_PATH,
      elasticsearch_url: ELASTICSEARCH_URL,
    }.merge(opts)

    %Q{
      type kibana_server
      bind #{merged[:bind]}
      port #{merged[:port]}
      mount #{merged[:mount]}
      access_log_path #{merged[:access_log_path]}
      elasticsearch_url #{merged[:elasticsearch_url]}
    }
  end

end
