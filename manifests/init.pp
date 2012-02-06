Class['thinkup::config'] -> Class['thinkup::server']
Class['thinkup::config'] -> Class['thinkup::database']
Class['thinkup::config'] -> Class['thinkup::server::database_tables']

class thinkup::config(
  $database_host,
  $database_user,
  $database_password,
  $database,
  $timezone = 'America/Los_Angeles',
  $password_salt
) { }

class thinkup::server($webserver = 'apache', $port = 80) {
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
    ensure  => '1.0-swellpath-20120122',
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
  $crawler_cron = '/etc/cron.hourly/thinkup_crawler'
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
}

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
    proxy              => 'http://thinkup',
    proxy_read_timeout => 3600,
  }
}

class thinkup::server::database_tables {
  $create_sql = '/var/www/thinkup/tmp/build-db_mysql.sql'
  file { $create_sql:
    ensure => present,
    source => '/var/www/thinkup/install/sql/build-db_mysql.sql'
  }

  Exec {
    path    => [ '/usr/local/bin', '/usr/bin', '/bin' ],
    require => tagged('mysqlserver') ? {
      true => Class['thinkup::database'],
      default => undef
    }
  }

  $mysql = "mysql -h${thinkup::config::database_host} -u${thinkup::config::database_user} -p${thinkup::config::database_password} ${thinkup::config::database}"
  exec { "import thinkup":
      command     => "${mysql} < ${create_sql} || rm ${create_sql}",
      #unless     => "echo 'SHOW TABLES' | ${mysql} | grep -q instances",
      refreshonly => true,
      subscribe   => File[$create_sql],
      before      => Exec['add tu_posts.last_updated']
  }

  exec { "add tu_posts.last_updated":
      command => "echo 'ALTER TABLE tu_posts ADD last_updated TIMESTAMP; UPDATE tu_posts SET last_updated = NOW();' | ${mysql}",
      unless  => "echo 'SHOW COLUMNS FROM tu_posts LIKE \"last_updated\";' | ${mysql} | grep -q last_updated",
      require => Exec['import thinkup']
  }
}

class thinkup::database($type = 'mysql', $admin_password) {
  case $type {
    'mysql': {
      if !defined(Class['mysql::server']) {
        class { 'mysql::server':
          config_hash => {
            'root_password' => $admin_password,
            'bind_address'  => tagged('thinkup::server') ?  {
              true  => '127.0.0.1',
              false => '0.0.0.0'
            }
          }
        }
      }

      mysql::db { $thinkup::config::database:
        user     => $thinkup::config::database_user,
        password => $thinkup::config::database_password,
        # TODO: restrict hosts
        host     => '%',
        grant    => ['all'],
      }

      include mysql::timezone

    }
    default: { fail("Unrecognized database type") }
  }
}

define thinkup::user($fullname = $title, $email, $password, $admin = 0, $crawl_automatically = true) {
  Class['thinkup::server::database_tables'] -> Thinkup::User[$title]
  Class['thinkup::proxy'] -> Thinkup::User[$title]

  Exec {
    path => [ '/usr/local/bin', '/usr/bin', '/bin' ]
  }

  $api_key = inline_template("<% require 'digest'; api_key = Digest::MD5.hexdigest('${email}' + '${password}'); %><%= api_key -%>")

  # creates a file containing sql to populate owner record, then execs mysql client
  # use generally-static salt so the template doesn't return different content on each run
  $sql_tmpl = "<% require 'digest';
    salt = Digest::SHA256.hexdigest('${thinkup::config::password_salt}' + '${email}');
    pass = Digest::SHA256.hexdigest('${password}' + salt); %>
    INSERT INTO tu_owners (`full_name`, `email`, `pwd`, `pwd_salt`, `is_activated`, `api_key`, `is_admin`)
    VALUES ('${fullname}', '${email}', '<%= pass -%>', '<%= salt -%>', 1, '<%= api_key -%>', ${admin})
    ON DUPLICATE KEY UPDATE full_name = '${fullname}', pwd = '<%= pass -%>', pwd_salt = '<%= salt -%>', is_activated = 1, api_key = '<%= api_key -%>', is_admin = ${admin};"
  $sql = inline_template($sql_tmpl)
  $sql_file = md5($sql)
  $sql_path = "/var/www/thinkup/tmp/${sql_file}"

  file { "${sql_path}":
    owner   => 'puppet',
    mode    => '600',
    content => $sql,
  }
  exec { "create owner $title":
    command => "mysql -h ${thinkup::config::database_host} -u${thinkup::config::database_user} -p${thinkup::config::database_password} ${thinkup::config::database} < ${sql_path}",
    refreshonly => true,
    subscribe => File[$sql_path]
  }

  $crawler_cron = '/etc/cron.hourly/thinkup_crawler'
  if $crawl_automatically {
    concat::fragment { "thinkup_crawler-${email}":
      target  => $crawler_cron,
      content => "/usr/bin/curl --silent 'http://${thinkup::proxy::listen_host}:${thinkup::proxy::listen_port}/crawler/run.php?un=${email}&as=${api_key}' | { grep -v '{\"result\":\"success\"}' || true; }\n"
    }
  }

}

class thinkup::plugins::facebook($app_id, $app_secret) {
  Class['thinkup::server::database_tables'] -> Class['thinkup::plugins::facebook']
  $sql = '/var/www/thinkup/tmp/configure-facebook.sql'
  $sql_tmpl = "REPLACE INTO tu_options SET namespace = 'plugin_options-2', option_name = 'facebook_app_id', option_value = '${app_id}', last_updated = NOW(), created = NOW();
    REPLACE INTO tu_options SET namespace = 'plugin_options-2', option_name = 'facebook_api_secret', option_value = '${app_secret}', last_updated = NOW(), created = NOW();"
  file { $sql:
    ensure => present,
    content => $sql_tmpl
  }

  Exec {
    path    => [ '/usr/local/bin', '/usr/bin', '/bin' ],
  }

  $mysql = "mysql -h${thinkup::config::database_host} -u${thinkup::config::database_user} -p${thinkup::config::database_password} ${thinkup::config::database}"
  exec {
    "configure facebook plugin":
      command     => "${mysql} < ${sql}",
      refreshonly => true,
      subscribe   => File[$sql];
  }
}

class thinkup::plugins::twitter($oauth_consumer_key, $oauth_consumer_secret) {
  Class['thinkup::server::database_tables'] -> Class['thinkup::plugins::twitter']
  $sql = '/var/www/thinkup/tmp/configure-twitter.sql'
  $sql_tmpl = "REPLACE INTO tu_options SET namespace = 'plugin_options-1', option_name = 'oauth_consumer_key', option_value = '${oauth_consumer_key}', last_updated = NOW(), created = NOW();
    REPLACE INTO tu_options SET namespace = 'plugin_options-1', option_name = 'oauth_consumer_secret', option_value = '${oauth_consumer_secret}', last_updated = NOW(), created = NOW();"
  file { $sql:
    ensure => present,
    content => $sql_tmpl
  }

  Exec {
    path    => [ '/usr/local/bin', '/usr/bin', '/bin' ],
  }

  $mysql = "mysql -h${thinkup::config::database_host} -u${thinkup::config::database_user} -p${thinkup::config::database_password} ${thinkup::config::database}"
  exec {
    "configure twitter plugin":
      command     => "${mysql} < ${sql}",
      refreshonly => true,
      subscribe   => File[$sql];
  }
}
