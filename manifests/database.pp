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
