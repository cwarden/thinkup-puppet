class thinkup::plugins::facebook($app_id, $app_secret) {
  Class['thinkup::server::database_tables'] -> Class['thinkup::plugins::facebook']
  $sql = '/var/www/thinkup/tmp/configure-facebook.sql'
  $sql_tmpl = "REPLACE INTO tu_options SET namespace = 'plugin_options-2', option_name = 'facebook_app_id', option_value = '${app_id}', last_updated = NOW(), created = NOW();
    REPLACE INTO tu_options SET namespace = 'plugin_options-2', option_name = 'facebook_api_secret', option_value = '${app_secret}', last_updated = NOW(), created = NOW();"
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
    "configure facebook plugin":
      command     => "${mysql} < ${sql}",
      refreshonly => true,
      subscribe   => File[$sql];
  }
}
