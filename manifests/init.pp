class thinkup($webserver = 'apache', $port = 80) {

  file { "thinkup_1.0_all.deb":
    path   => "/var/cache/apt/archives/thinkup_1.0_all.deb",
    source => "puppet:///modules/thinkup/thinkup_1.0_all.deb",
  }
  Package { ensure => latest }
  package {
    'php5-mysql':;
    'php5-curl':;
    'php5-gd':;
  }
  case $webserver {
    /apache2?/: {
      Package['thinkup'] -> Apache::Vhost['thinkup']
      Class['Apache::Php'] -> Package['thinkup']
      class {
        'apache':
          require => Package['php5-mysql', 'php5-curl', 'php5-gd'],
          subscribe => Package['php5-mysql', 'php5-curl', 'php5-gd'];
        'apache::php':;
        }
      apache::vhost { 'thinkup':
          port    => $port,
          ssl     => false,
          docroot => '/var/www/thinkup',
      }
    }
    'nginx': {
      # this doesn't work yet; need to configure fastcgi for php.
      # Use think::proxy to proxy requests to apache instead.
      Package['thinkup'] -> Nginx::Resource::Vhost['thinkup']
      Package['php5-cgi'] -> Package['thinkup']
      class { 'nginx':; }
      nginx::resource::vhost { 'thinkup':
        ensure => present,
        www_root => '/var/www/thinkup',
      }
      package { 'php5-cgi': require => Package['php5']; 'php5':; }
    }
  }

  package { "thinkup":
    ensure  => "present",
    provider => "dpkg",
    source  => '/var/cache/apt/archives/thinkup_1.0_all.deb',
    require => [File['thinkup_1.0_all.deb'], Package['php5-mysql']],
  }

  file { "/var/www/thinkup/_lib/view/compiled_view/":
    ensure => directory,
    mode   => 700,
    owner  => "www-data",
    group  => "www-data",
  }
}

class thinkup::proxy($listen_host, $listen_port = 80, $destination_host, $destination_port) {
  class { 'nginx': }
  nginx::resource::upstream { 'thinkup':
    ensure  => present,
    members => [
      "${destination_host}:${destination_port}"
    ],
  }
  nginx::resource::vhost { "${listen_host}:${listen_port}":
    listen_port => $listen_port,
    ensure   => present,
    proxy  => 'http://thinkup',
  }
}
