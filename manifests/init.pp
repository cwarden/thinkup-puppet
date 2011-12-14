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
    ensure  => directory,
    mode    => 700,
    owner   => "www-data",
    group   => "www-data",
    require => Package['thinkup']
  }

  file { "/var/www/thinkup/logs/":
    ensure  => directory,
    mode    => 700,
    recurse => true,
    owner   => "www-data",
    group   => "www-data",
    require => Package['thinkup']
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

class thinkup::server::database_tables {
  $create_sql = '/var/www/thinkup/tmp/build-db_mysql.sql'
  file { $create_sql:
    ensure => present,
    source => '/var/www/thinkup/install/sql/build-db_mysql.sql'
  }

  Exec {
    path    => [ '/usr/local/bin', '/usr/bin', '/bin' ],
    require => tagged('mysqlserver') ? { true => Class['thinkup::database'], default => undef }
  }

  $mysql = "mysql -h${thinkup::config::database_host} -u${thinkup::config::database_user} -p${thinkup::config::database_password} ${thinkup::config::database}"
  exec {
    "import thinkup":
      command     => "${mysql} < ${create_sql}",
      #unless     => "echo 'SHOW TABLES' | ${mysql} | grep -q instances",
      refreshonly => true,
      subscribe   => File[$create_sql];
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

    }
    default: { fail("Unrecognized database type") }
  }
}

define thinkup::user($fullname = $title, $email, $password, $admin = 0) {
  Class['thinkup::server::database_tables'] -> Thinkup::User[$title]

  Exec {
    path => [ '/usr/local/bin', '/usr/bin', '/bin' ]
  }

  # creates a file containing sql to populate owner record, then execs mysql client
  # use generally-static salt so the template doesn't return different content on each run
  $sql_tmpl = "<% require 'digest';
    salt = Digest::SHA256.hexdigest('${thinkup::config::password_salt}' + '${email}');
    pass = Digest::SHA256.hexdigest('${password}' + salt) %>
    INSERT INTO tu_owners (`full_name`, `email`, `pwd`, `pwd_salt`, `is_activated`, `is_admin`)
    VALUES ('${fullname}', '${email}', '<%= pass -%>', '<%= salt -%>', 1, ${admin})
    ON DUPLICATE KEY UPDATE full_name = '${fullname}', pwd = '<%= pass -%>', pwd_salt = '<%= salt -%>', is_activated = 1, is_admin = ${admin};"
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
}
