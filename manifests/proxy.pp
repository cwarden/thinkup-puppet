class thinkup::proxy($listen_host, $listen_port = 80, $destination_host, $destination_port) {
  include nginx
  nginx::resource::upstream { 'thinkup':
    ensure  => present,
    members => [
      "${destination_host}:${destination_port}"
    ],
  }
  nginx::resource::vhost { "${listen_host}":
    listen_port        => $listen_port,
    ensure             => present,
    proxy              => 'http://thinkup/',
    proxy_read_timeout => 3600,
  }
}

