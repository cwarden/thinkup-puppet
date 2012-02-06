<?php
/************************************************/
/***  APPLICATION CONFIG                      ***/
/************************************************/

// Application title
$THINKUP_CFG['app_title']                 = 'ThinkUp';

// Public path of thinkup's /webapp/ folder on your web server.
// For example, if the /webapp/ folder is located at http://yourdomain/thinkup/, set to '/thinkup/'.
$THINKUP_CFG['site_root_path']            = '/';

// Full server path to /thinkup/ folder.
$THINKUP_CFG['source_root_path']          = realpath(dirname(__FILE__)) . '/';

// Your timezone
$THINKUP_CFG['timezone']                  = '<%= timezone -%>';

// Toggle Smarty caching. true: Smarty caching on, false: Smarty caching off
$THINKUP_CFG['cache_pages']               = true;

// The crawler, when triggered by requests to the RSS feed, will only launch if it's been
// 20 minutes or more since the last crawl.
$THINKUP_CFG['rss_crawler_refresh_rate']  = 20;

/************************************************/
/***  DATABASE CONFIG                         ***/
/************************************************/

$THINKUP_CFG['db_host']                   = '<%= database_host -%>'; //On a shared host? Try mysql.yourdomain.com, or see your web host's documentation.
$THINKUP_CFG['db_type']                   = 'mysql';
$THINKUP_CFG['db_user']                   = '<%= database_user -%>';
$THINKUP_CFG['db_password']               = '<%= database_password -%>';
$THINKUP_CFG['db_name']                   = '<%= database -%>';
$THINKUP_CFG['db_socket']                 = '';
$THINKUP_CFG['db_port']                   = '';
$THINKUP_CFG['table_prefix']              = 'tu_';

/************************************************/
/***  DEVELOPER CONFIG                        ***/
/************************************************/

// Full server path to crawler.log.
$THINKUP_CFG['log_location']              = '/var/log/thinkup/crawler.log';

// Verbosity of log. 0 is everything, 1 is user messages, 2 is errors only
$THINKUP_CFG['log_verbosity']             = 0;

// Full server path to stream processor log.
$THINKUP_CFG['stream_log_location']       = '/var/log/thinkup/stream.log';

// Full server path to sql.log. To not log queries, set to null.
$THINKUP_CFG['sql_log_location']          = '/var/log/thinkup/sql.log';

// How many seconds does a query take before it gets logged as a slow query?
$THINKUP_CFG['slow_query_log_threshold']  = 2.0;

$THINKUP_CFG['debug']                     = false;

$THINKUP_CFG['enable_profiler']           = false;

// Set this to true if you want your PDO object's database connection's charset to be explicitly set to utf8.
// If false (or unset), the database connection's charset will not be explicitly set.
$THINKUP_CFG['set_pdo_charset']           = false;
