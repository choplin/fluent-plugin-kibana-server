# Fluent::Plugin::KibanaServer

Fluent plugin to serve [Kibana](https://github.com/elasticsearch/kibana)

## Installation

`$ fluent-gem install fluent-plugin-kibana-server`

## Configuration

### Example

```
<source **>
  type kibana_server
  bind 0.0.0.0
  port 24300
  mount /kibana/
  access_log_path /Users/okuno/tmp/var/log/kibana/access.log
  elasticsearch_url http://localhost:9200
</source>
```

### Parameter

|parameter|description|default|
|---|---|---|
|bind|Local address for the server to bind to|0.0.0.0|
|port|Port to listen on|24300|
|mount|Root path of Kibana||
|access_log_path|Path to access log. No logs will be written if this parameter is ommited.||
|elasticsearch_url|URL of elasticsearch. This parameter is used in config.js of Kibana.||

## TODO

pathches welcome!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
