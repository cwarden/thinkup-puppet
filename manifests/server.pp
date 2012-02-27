class thinkup::server($webserver = 'apache', $port = 80, $site_root_path = '/') {
  $database_host = $thinkup::config::database_host
  $database_user = $thinkup::config::database_user
  $database_password = $thinkup::config::database_password
  $database = $thinkup::config::database
  $timezone = $thinkup::config::timezone

  include mysql
  if !defined(Apt::Source['swellpath']) {
    apt::source { "swellpath":
      location    => "http://swdeb.s3.amazonaws.com",
      release     => "swellpath",
      repos       => "main",
      key         => "4EF797A0",
      key_server  => "subkeys.pgp.net",
      include_src => false,
    }
  }
  Package { ensure => latest, require => Apt::Source['swellpath'] }
  package {
    'php5':;
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
          require => Package['php5', 'php5-mysql', 'php5-curl', 'php5-gd'],
          subscribe => Package['php5', 'php5-mysql', 'php5-curl', 'php5-gd'];
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
    ensure  => 'latest',
  }

  file { "/var/www/thinkup/_lib/view/compiled_view/":
    ensure  => directory,
    mode    => 700,
    owner   => "www-data",
    group   => "www-data",
    require => Package['thinkup']
  }

  # TODO: move this into the debian package
  file { "/etc/logrotate.d/thinkup":
    ensure  => file,
    mode    => 644,
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/thinkup/logrotate.conf',
  }

  file {
     "/var/run/thinkup/":
      ensure  => directory,
      mode    => 700,
      recurse => true,
      owner   => "www-data",
      group   => "www-data",
      require => Package['thinkup'];
     "/var/log/thinkup/":
      ensure  => directory,
      mode    => 700,
      recurse => true,
      owner   => "www-data",
      group   => "www-data",
      require => Package['thinkup'];
    "/var/www/thinkup/logs/":
      ensure => absent,
      force  => true;
    "/var/www/thinkup/webapp/_lib/view/compiled_view/":
      ensure => absent,
      force  => true;
  }

  file { "/var/www/thinkup/tmp/":
    ensure  => directory,
    mode    => 700,
    recurse => true,
    purge   => true,
    owner   => "root",
    group   => "root",
    require => Package['thinkup']
  }

  file { "/var/www/thinkup/config.inc.php":
    content => template('thinkup/config.inc.php'),
    require => Package['thinkup']
  }

  include concat::setup
  # old location of cron script
  file { '/etc/cron.hourly/thinkup_crawler':
    ensure => absent
  }

  $crawler_cron = '/var/run/thinkup/thinkup_crawler'
  concat::fragment { "${crawler_cron}-header}":
    target  => $crawler_cron,
    content => "#!/bin/sh\n",
    order   => '01',
  }
  concat { $crawler_cron:
    owner => 'root',
    group => 'root',
    mode  => 700,
  }

  cron { 'run thinkup crawler':
    user    => root,
    command => $crawler_cron,
    hour    => '*/4',
    minute  => fqdn_rand(59, 4),
  }
}
