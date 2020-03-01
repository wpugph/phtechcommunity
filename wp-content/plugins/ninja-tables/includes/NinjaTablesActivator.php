<?php namespace NinjaTables\Classes;

/**
 * Fired during plugin activation
 *
 * @link       https://authlab.io
 * @since      1.0.0
 *
 * @package    Wp_table_data_press
 * @subpackage Wp_table_data_press/includes
 */

/**
 * Fired during plugin activation.
 *
 * This class defines all code necessary to run during the plugin's activation.
 *
 * @since      1.0.0
 * @package    Wp_table_data_press
 * @subpackage Wp_table_data_press/includes
 * @author     Shahjahan Jewel <cep.jewel@gmail.com>
 */
class NinjaTablesActivator {

	/**
	 * Short Description. (use period)
	 *
	 * Long Description.
	 *
	 * @since    1.0.0
	 */
	public static function activate() {
		self::create_datatables_table();
	}

	/**
	 * Create Table for datatable which will hold the primary info of a table
	 *
	 * @since    1.0.0
	 */
	public static function create_datatables_table() {
		global $wpdb;
		$charset_collate = $wpdb->get_charset_collate();
		$table_name      = $wpdb->prefix . ninja_tables_db_table_name();
		if ( $wpdb->get_var( "SHOW TABLES LIKE '$table_name'" ) != $table_name ) {
			$sql = "CREATE TABLE $table_name (
				id int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
				position int(11),
				table_id int(11) NOT NULL,
				attribute varchar(255) NOT NULL,
				value longtext,
				created_at timestamp NULL,
				updated_at timestamp NULL
			) $charset_collate;";

			require_once( ABSPATH . 'wp-admin/includes/upgrade.php' );
			dbDelta( $sql );
		}
	}

}
