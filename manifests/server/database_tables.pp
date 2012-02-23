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
