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

      if @thread
        @thread.join
        @thread = nil
      end
    end

    private

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
