<?php
/**
 * This config file is yours to hack on. It will work out of the box on Pantheon
 * but you may find there are a lot of neat tricks to be used here.
 *
 * See our documentation for more details:
 *
 * https://pantheon.io/docs
 */

/**
 * Pantheon platform settings. Everything you need should already be set.
 */
if (file_exists(dirname(__FILE__) . '/wp-config-pantheon.php') && isset($_ENV['PANTHEON_ENVIRONMENT'])) {
	require_once(dirname(__FILE__) . '/wp-config-pantheon.php');

/**
 * Local configuration information.
 *
 * If you are working in a local/desktop development environment and want to
 * keep your config separate, we recommend using a 'wp-config-local.php' file,
 * which you should also make sure you .gitignore.
 */
} elseif (file_exists(dirname(__FILE__) . '/wp-config-local.php') && !isset($_ENV['PANTHEON_ENVIRONMENT'])){
	# IMPORTANT: ensure your local config does not include wp-settings.php
	require_once(dirname(__FILE__) . '/wp-config-local.php');

/**
 * This block will be executed if you are NOT running on Pantheon and have NO
 * wp-config-local.php. Insert alternate config here if necessary.
 *
 * If you are only running on Pantheon, you can ignore this block.
 */
} else {
	define('DB_NAME',          'database_name');
	define('DB_USER',          'database_username');
	define('DB_PASSWORD',      'database_password');
	define('DB_HOST',          'database_host');
	define('DB_CHARSET',       'utf8');
	define('DB_COLLATE',       '');
	define('AUTH_KEY',         'put your unique phrase here');
	define('SECURE_AUTH_KEY',  'put your unique phrase here');
	define('LOGGED_IN_KEY',    'put your unique phrase here');
	define('NONCE_KEY',        'put your unique phrase here');
	define('AUTH_SALT',        'put your unique phrase here');
	define('SECURE_AUTH_SALT', 'put your unique phrase here');
	define('LOGGED_IN_SALT',   'put your unique phrase here');
	define('NONCE_SALT',       'put your unique phrase here');
}


/** Standard wp-config.php stuff from here on down. **/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each a unique
 * prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * You may want to examine $_ENV['PANTHEON_ENVIRONMENT'] to set this to be
 * "true" in dev, but false in test and live.
 */
if ( ! defined( 'WP_DEBUG' ) ) {
	define('WP_DEBUG', false);
}

if ( file_exists( dirname( __FILE__ ) . '/wp-content/uploads/private/wp-config-redirect.php' ) && ! isset( $_ENV['PANTHEON_ENVIRONMENT'] ) ) {
	require_once dirname( __FILE__ ) . '/wp-content/uploads/private/wp-config-redirect.php';
}

/* That's all, stop editing! Happy Pressing. */

// All Pantheon Environments.
if (defined('PANTHEON_ENVIRONMENT')) {
	// Turns on WordPress debug settings in development and multidev environments, and disables in test and live.
	if (!in_array(PANTHEON_ENVIRONMENT, array('test', 'live'))) {
	  // Debugging enabled.
	  if (!defined('WP_DEBUG')) {
		define( 'WP_DEBUG', false );
	  }
	  if (!defined('WP_DISABLE_FATAL_ERROR_HANDLER')) {
		define( 'WP_DISABLE_FATAL_ERROR_HANDLER', false ); // 5.2 and later
	  }
	 if (!defined('WP_DEBUG_DISPLAY')) {
		define( 'WP_DEBUG_DISPLAY', false ); // requires WP_DISABLE_FATAL_ERROR_HANDLER set to true
	  }
	  define( 'WP_DEBUG_LOG', __DIR__ . '/wp-content/uploads/debug.log' ); // Moves the log file to a location writable while in git mode. Only works in WP 5.1
	}
	// WordPress debug settings in Test and Live environments.
	else {
	  // Debugging disabled.
	  ini_set( 'log_errors','On' );
	  ini_set( 'display_errors','On' );
	  ini_set( 'error_reporting', E_ALL );
	  define( 'WP_DEBUG', true );
	  define( 'WP_DEBUG_LOG', true );
	  define( 'WP_DISABLE_FATAL_ERROR_HANDLER', true );
	  define( 'WP_DEBUG_DISPLAY', true );
	}
  }


/** Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');

/** Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');
