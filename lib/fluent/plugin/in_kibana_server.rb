module Fluent
  class KibanaServerInput < Input
    Plugin.register_input('kibana_server', self)

    PATH_TO_KIBANA = File.join(File.dirname(__FILE__), '../../../vendor/kibana-3.0.0milestone4')
    CONFIG_JS_PATH = File.join(PATH_TO_KIBANA, 'config.js')

    require 'webrick'

    config_param :bind, :string, :default => '0.0.0.0'
    config_param :port, :integer, :default => 24300
    config_param :mount, :string, :default => '/'
    config_param :access_log_path, :string, :default => nil
    config_param :elasticsearch_url, :string, :default => nil
    config_param :remove_indices_before, :time, :default => nil

    def start
      $log.info "listening http server for kinaba on http://#{@bind}:#{@port}#{@mount}"

      @access_log = File.open(@access_log_path, 'a') if @access_log_path

      File.open(CONFIG_JS_PATH, 'w') {|f| f.write(kibana_config)}

      @srv = WEBrick::HTTPServer.new({
          :BindAddress => @bind,
          :Port => @port,
          :Logger => WEBrick::Log.new(STDERR, WEBrick::Log::FATAL),
          :AccessLog => @access_log ? [[@access_log, WEBrick::AccessLog::CLF]] : [],
        })

      @srv.mount(@mount, WEBrick::HTTPServlet::FileHandler, PATH_TO_KIBANA)

      setup_deleter if @remove_indices_before

      @thread = Thread.new { @srv.start }
    end

    def shutdown
      if @srv
        @srv.shutdown
        @srv = nil
      end

      if @access_log and (not @access_log.closed?)
        @access_log.close
      end

      if @loop
        @loop.watchers.each { |w| w.detach }
        @loop.stop
        @delete_thread.join
      end

      if @thread
        @thread.join
        @thread = nil
      end
    end

    private

    def setup_deleter
      @next_time = Time.now + 24 * 60 * 60
      @loop = Coolio::Loop.new
      # use 10 second interval for shutdown. If cool.io supports detach timer loop with signal, use 1 day interval.
      @loop.attach(OutdatedIndicesDeleter.new(10, method(:delete_outdated_indices)))
      @delete_thread = Thread.new {
        begin
          @loop.run
        rescue => e
          $log.error "unexpected error at deleter", :error_class => e.class, :error => e
          $log.error_backtrace
        end
      }
    end

    def delete_outdated_indices
      require 'elasticsearch'

      return if skip_delete_process?

      key = expired_key
      client = Elasticsearch::Client.new(:hosts => @elasticsearch_url)
      indices = client.indices.status['indices'].keys.select { |k| k.start_with?('logstash-') }
      outdated = indices.select { |index| index <= key }
      client.indices.delete(:index => outdated)
      $log.debug "Deleted indices: #{outdated.join(', ')}"
      @next_time += 24 * 60 * 60
    rescue => e
      $log.error "Failed to delete outdated indices. Try next time.", :error_class => e.class, :error => e
      $log.error_backtrace
    end

    def expired_key
      t = Time.now - (@remove_indices_before * 24 * 60 * 60)
      "logstash-#{t.strftime("%Y.%m.%d")}"
    end

    def skip_delete_process?
      Time.now < @next_time
    end

    class OutdatedIndicesDeleter < Coolio::TimerWatcher
      def initialize(interval, callback)
        super(interval, true)
        @callback = callback
      end

      def on_timer
        @callback.call
      end
    end

    def kibana_config
      elasticsearch = if @elasticsearch_url
                        %Q{"#{@elasticsearch_url}"}
                      else
                        %Q{"http://"+window.location.hostname+":9200"}
                      end
      <<-CONFIG
/**
 * These is the app's configuration, If you need to configure
 * the default dashboard, please see dashboards/default
 */
define(['settings'],
function (Settings) {
  

  return new Settings({

    /**
     * URL to your elasticsearch server. You almost certainly don't
     * want 'http://localhost:9200' here. Even if Kibana and ES are on
     * the same host
     *
     * By default this will attempt to reach ES at the same host you have
     * elasticsearch installed on. You probably want to set it to the FQDN of your
     * elasticsearch host
     * @type {String}
     */
    elasticsearch: #{elasticsearch},

    /**
     * The default ES index to use for storing Kibana specific object
     * such as stored dashboards
     * @type {String}
     */
    kibana_index: "kibana-int",

    /**
     * Panel modules available. Panels will only be loaded when they are defined in the
     * dashboard, but this list is used in the "add panel" interface.
     * @type {Array}
     */
    panel_names: [
      'histogram',
      'map',
      'pie',
      'table',
      'filtering',
      'timepicker',
      'text',
      'fields',
      'hits',
      'dashcontrol',
      'column',
      'derivequeries',
      'trends',
      'bettermap',
      'query',
      'terms'
    ]
  });
});
      CONFIG
    end
  end
end
