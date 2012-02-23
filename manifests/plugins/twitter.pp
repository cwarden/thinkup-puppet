class thinkup::plugins::twitter($oauth_consumer_key, $oauth_consumer_secret) {
  Class['thinkup::server::database_tables'] -> Class['thinkup::plugins::twitter']
  $sql = '/var/www/thinkup/tmp/configure-twitter.sql'
  $sql_tmpl = "REPLACE INTO tu_options SET namespace = 'plugin_options-1', option_name = 'oauth_consumer_key', option_value = '${oauth_consumer_key}', last_updated = NOW(), created = NOW();
    REPLACE INTO tu_options SET namespace = 'plugin_options-1', option_name = 'oauth_consumer_secret', option_value = '${oauth_consumer_secret}', last_updated = NOW(), created = NOW();"
  file { $sql:
    ensure => present,
    mode   => 400,
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
