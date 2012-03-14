## thinkup module

### Overview

This module can install and configure ThinkUp on a Debian-based system.

### Example

````
node thinkupserver {
  class {
    'thinkup::config':
	   # FIXME: the same salt is currently used for all passwords
      password_salt => 'a39f3543913d764ae41ec005bc0a21f5',
      database => 'thinkup',
      database_host => 'localhost'
      database_user => 'thinkup',
      database_password => 'thinkaboutit';
  }
 
  # Install MySQL server if not installed, and create thinkup database
  class {
    'thinkup::database':
      admin_password => 'root password';
  }
  
  # Install ThinkUp and web server
  class {
    'thinkup::server':
      webserver => 'apache',
      site_root_path => '/thinkup/',
      port => 8888;
    'thinkup::proxy':
      listen_host => 'example.com',
      listen_port => 80,
      destination_host => 'localhost',
      destination_port => 8888;
    'thinkup::server::database_tables':;
    'thinkup::plugins::facebook':
      app_id => 'your app id',
      app_secret => 'your app secret';
    'thinkup::plugins::twitter':
      oauth_consumer_key => 'your consumer key',
      oauth_consumer_secret => 'your consumer secret';
  }
}
````
