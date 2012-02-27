define thinkup::user($fullname = $name,
  $email,
  $password,
  $admin = 0,
  $crawl_automatically = true,
  $overwrite_password = true  # if user already exists, should the password be updated?
) {
  Class['thinkup::server::database_tables'] -> Thinkup::User[$name]
  Class['thinkup::proxy'] -> Thinkup::User[$name]

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
    ON DUPLICATE KEY UPDATE full_name = '${fullname}', is_activated = 1
      <% if overwrite_password %>
        , pwd = '<%= pass -%>', pwd_salt = '<%= salt -%>', api_key = '<%= api_key -%>'
      <% end %>
      , is_admin = ${admin};"
  $sql = inline_template($sql_tmpl)
  $sql_file = md5($sql)
  $sql_path = "/var/www/thinkup/tmp/${sql_file}"

  file { "${sql_path}":
    owner   => 'puppet',
    mode    => '600',
    content => $sql,
  }
  exec { "create owner $name":
    command => "mysql -h ${thinkup::config::database_host} -u${thinkup::config::database_user} -p${thinkup::config::database_password} ${thinkup::config::database} < ${sql_path}",
    refreshonly => true,
    subscribe => File[$sql_path]
  }

  if $crawl_automatically {
    concat::fragment { "thinkup_crawler-${email}":
      target  => $thinkup::server::crawler_cron,
      content => "/usr/bin/curl --silent 'http://${thinkup::proxy::listen_host}:${thinkup::proxy::listen_port}/crawler/run.php?un=${email}&as=${api_key}' | { grep -v '{\"result\":\"success\"}' || true; }\n"
    }
  }

}

