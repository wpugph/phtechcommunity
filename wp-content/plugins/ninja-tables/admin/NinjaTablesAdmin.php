<?php
/*
 * Do Not USE namespace because The Pro Add-On Used this Class
 */

use NinjaTable\TableDrivers\NinjaFooTable;
use NinjaTables\Classes\NinjaTablesTablePressMigration;
use NinjaTables\Classes\NinjaTablesUltimateTableMigration;

/**
 * The admin-specific functionality of the plugin.
 *
 * @link       https://authlab.io
 * @since      1.0.0
 *
 * @package    ninja-tables
 * @subpackage ninja-tables/admin
 */
class NinjaTablesAdmin {
	/**
	 * The ID of this plugin.
	 *
	 * @since    1.0.0
	 * @access   private
	 * @var      string $plugin_name The ID of this plugin.
	 */
	private $plugin_name;

	/**
	 * Custom Post Type Name
	 *
	 * @since    1.0.0
	 * @access   private
	 * @var      string $cpt_name .
	 */
	private $cpt_name;

	/**
	 * The version of this plugin.
	 *
	 * @since    1.0.0
	 * @access   private
	 * @var      string $version The current version of this plugin.
	 */
	private $version;

	/**
	 * Initialize the class and set its properties.
	 *
	 * @since    1.0.0
	 *
	 * @param      string $plugin_name The name of this plugin.
	 * @param      string $version     The version of this plugin.
	 */
	public function __construct( $plugin_name = 'ninja-tables', $version = NINJA_TABLES_VERSION ) {
		$this->plugin_name = $plugin_name;
		$this->version     = $version;
		$this->cpt_name    = 'ninja-table';
	}

	/**
	 * Register form post types
	 *
	 * @return void
	 */
	public function register_post_type() {
		register_post_type( $this->cpt_name, array(
			'label'           => __( 'Ninja Tables', 'ninja-tables' ),
			'public'          => false,
			'show_ui'         => true,
			'show_in_menu'    => false,
			'capability_type' => 'post',
			'hierarchical'    => false,
			'query_var'       => false,
			'supports'        => array( 'title' ),
			'labels'          => array(
				'name'               => __( 'Ninja Tables', 'ninja-tables' ),
				'singular_name'      => __( 'Table', 'ninja-tables' ),
				'menu_name'          => __( 'Ninja Tables', 'ninja-tables' ),
				'add_new'            => __( 'Add Table', 'ninja-tables' ),
				'add_new_item'       => __( 'Add New Table', 'ninja-tables' ),
				'edit'               => __( 'Edit', 'ninja-tables' ),
				'edit_item'          => __( 'Edit Table', 'ninja-tables' ),
				'new_item'           => __( 'New Table', 'ninja-tables' ),
				'view'               => __( 'View Table', 'ninja-tables' ),
				'view_item'          => __( 'View Table', 'ninja-tables' ),
				'search_items'       => __( 'Search Table', 'ninja-tables' ),
				'not_found'          => __( 'No Table Found', 'ninja-tables' ),
				'not_found_in_trash' => __( 'No Table Found in Trash', 'ninja-tables' ),
				'parent'             => __( 'Parent Table', 'ninja-tables' ),
			),
		) );
	}


	/**
	 * Adds a settings page link to a menu
	 *
	 * @link  https://codex.wordpress.org/Administration_Menus
	 * @since 1.0.0
	 * @return void
	 */
	public function add_menu() {
		global $submenu;
		$capability = ninja_table_admin_role();

		// Continue only if the current user has
		// the capability to manage ninja tables
		if ( ! $capability ) {
			return;
		}

		// Top-level page
		$menuName = __( 'NinjaTables', 'ninja-tables' );
		if ( defined( 'NINJATABLESPRO' ) ) {
			$menuName .= ' Pro';
		}

		add_menu_page(
			$menuName,
			$menuName,
			$capability,
			'ninja_tables',
			array( $this, 'main_page' ),
			ninja_table_get_icon_url(),
			25
		);

		$submenu['ninja_tables']['all_tables'] = array(
			__( 'All Tables', 'ninja-tables' ),
			$capability,
			'admin.php?page=ninja_tables#/',
		);

		$submenu['ninja_tables']['tools'] = array(
			__( 'Tools', 'ninja-tables' ),
			$capability,
			'admin.php?page=ninja_tables#/tools',
			'',
			'ninja_table_tools_menu'
		);

		$submenu['ninja_tables']['import'] = array(
			__( 'Import a Table', 'ninja-tables' ),
			$capability,
			'admin.php?page=ninja_tables#/tools',
			'',
			'ninja_table_import_menu'
		);

		if ( ! defined( 'NINJATABLESPRO' ) ) {
			$submenu['ninja_tables']['upgrade_pro'] = array(
				__( '<span style="color:#f39c12;">Get Pro</span>', 'ninja-tables' ),
				$capability,
				'https://wpmanageninja.com/downloads/ninja-tables-pro-add-on/?utm_source=ninja-tables&utm_medium=wp&utm_campaign=wp_plugin&utm_term=upgrade_menu',
				'',
				'ninja_table_upgrade_menu'
			);
		} elseif ( defined( 'NINJATABLESPRO_SORTABLE' ) ) {
			$license = get_option( '_ninjatables_pro_license_status' );
			if ( $license != 'valid' ) {
				$submenu['ninja_tables']['activate_license'] = array(
					'<span style="color:#f39c12;">Activate License</span>',
					$capability,
					'admin.php?page=ninja_tables#/tools?active_menu=license',
					'',
					'ninja_table_license_menu'
				);
			}
		}

		$submenu['ninja_tables']['help'] = array(
			__( 'Help', 'ninja-tables' ),
			$capability,
			'admin.php?page=ninja_tables#/help'
		);
	}

	public function main_page() {
		$this->enqueue_data_tables_scripts();

		include( plugin_dir_path( __FILE__ ) . 'partials/wp_data_tables_display.php' );
	}

	/**
	 * Register the stylesheets for the admin area.
	 *
	 * @since    1.0.0
	 */
	public function enqueue_styles() {
		$vendorSrc = plugin_dir_url( __DIR__ ) . "assets/css/ninja-tables-vendor.css";

		if ( is_rtl() ) {
			$vendorSrc = plugin_dir_url( __DIR__ ) . "assets/css/ninja-tables-vendor-rtl.css";
		}

		wp_enqueue_style(
			$this->plugin_name . '-vendor',
			$vendorSrc,
			[],
			$this->version,
			'all'
		);

		wp_enqueue_style(
			$this->plugin_name,
			plugin_dir_url( __DIR__ ) . "assets/css/ninja-tables-admin.css",
			array(),
			$this->version,
			'all'
		);
	}

	/**
	 * Register the JavaScript for the admin area.
	 *
	 * @since    1.0.0
	 */
	public function enqueue_scripts() {
		if ( function_exists( 'wp_enqueue_editor' ) ) {
			wp_enqueue_editor();
			wp_enqueue_media();
		}

		wp_enqueue_script(
			$this->plugin_name,
			plugin_dir_url( __DIR__ ) . "assets/js/ninja-tables-admin.js",
			array( 'jquery' ),
			$this->version,
			false
		);

		$fluentUrl = admin_url( 'plugin-install.php?s=FluentForm&tab=search&type=term' );

		$isInstalled   = defined( 'FLUENTFORM' ) || defined( 'NINJATABLESPRO' );
		$dismissed     = false;
		$dismissedTime = get_option( '_ninja_tables_plugin_suggest_dismiss' );

		if ( $dismissedTime ) {
			if ( ( time() - intval( $dismissedTime ) ) < 518400 ) {
				$dismissed = true;
			}
		} else {
			$dismissed = true;
			update_option( '_ninja_tables_plugin_suggest_dismiss', time() - 345600 );
		}

		wp_localize_script( $this->plugin_name, 'ninja_table_admin', array(
			'img_url'                  => plugin_dir_url( __DIR__ ) . "assets/img/",
			'fluentform_url'           => $fluentUrl,
			'fluent_wp_url'            => 'https://wordpress.org/plugins/fluentform/',
			'dismissed'                => $dismissed,
			'isInstalled'              => $isInstalled,
			'hasPro'                   => defined( 'NINJATABLESPRO' ),
			'hasSortable'              => defined( 'NINJATABLESPRO_SORTABLE' ),
			'ace_path_url'             => plugin_dir_url( __DIR__ ) . "assets/libs/ace",
			'upgradeGuide'             => 'https://wpmanageninja.com/r/docs/ninja-tables/how-to-install-and-upgrade/#upgrade',
			'hasValidLicense'          => get_option( '_ninjatables_pro_license_status' ),
			'i18n'                     => \NinjaTables\Classes\I18nStrings::getStrings(),
			'preview_required_scripts' => [
				plugin_dir_url( __DIR__ ) . "assets/css/ninjatables-public.css",
				plugin_dir_url( __DIR__ ) . "public/libs/footable/js/footable.min.js",
			]
		) );

		// Elementor plugin have a bug where they throw error to parse #url, and I really don't know why they want to parse
		// other plugin's page's uri. They should fix it.
		// For now I am de-registering their script in ninja-table admin pages.
		wp_deregister_script( 'elementor-admin-app' );
	}

	public function enqueue_data_tables_scripts() {
		$this->enqueue_scripts();
		$this->enqueue_styles();
	}

	public function ajax_routes() {
		if ( ! ninja_table_admin_role() ) {
			return;
		}

		$valid_routes = array(
			'get-all-tables'           => 'getAllTables',
			'store-a-table'            => 'storeTable',
			'delete-a-table'           => 'deleteTable',
			'import-table'             => 'importTable',
			'import-table-from-plugin' => 'importTableFromPlugin',
			'get-tables-from-plugin'   => 'getTablesFromPlugin',
			'update-table-settings'    => 'updateTableSettings',
			'get-table-settings'       => 'getTableSettings',
			'get-table-data'           => 'getTableData',
			'store-table-data'         => 'storeData',
			'edit-data'                => 'editData',
			'delete-data'              => 'deleteData',
			'upload-data'              => 'uploadData',
			'duplicate-table'          => 'duplicateTable',
			'export-data'              => 'exportData',
			'dismiss_fluent_suggest'   => 'dismissPluginSuggest',
			'save_custom_css'          => 'saveCustomCSS',
			'get_access_roles'         => 'getAccessRoles',
			'get_table_preview_html'   => 'getTablePreviewHtml'
		);

		$requested_route = $_REQUEST['target_action'];
		if ( isset( $valid_routes[ $requested_route ] ) ) {
			$this->{$valid_routes[ $requested_route ]}();
		}

		wp_die();
	}

	public function getAllTables() {
		$perPage = intval( $_REQUEST['per_page'] ) ?: 10;

		$currentPage = intval( $_GET['page'] );

		$skip = $perPage * ( $currentPage - 1 );

		$args = array(
			'posts_per_page' => $perPage,
			'offset'         => $skip,
			'orderby'        => 'date',
			'order'          => 'DESC',
			'post_type'      => $this->cpt_name,
			'post_status'    => 'any',

		);

		if ( isset( $_REQUEST['search'] ) && $_REQUEST['search'] ) {
			$args['s'] = sanitize_text_field( $_REQUEST['search'] );
		}

		$tables = get_posts( $args );

		foreach ( $tables as $table ) {
			$table->preview_url = site_url( '?ninjatable_preview=' . $table->ID );
		}

		$total    = wp_count_posts( 'ninja-table' );
		$total    = intval( $total->publish );
		$lastPage = ceil( $total / $perPage );

		wp_send_json( array(
			'total'        => $total,
			'per_page'     => $perPage,
			'current_page' => $currentPage,
			'last_page'    => ( $lastPage ) ? $lastPage : 1,
			'data'         => $tables,
		), 200 );
	}

	public function storeTable() {
		if ( ! $_REQUEST['post_title'] ) {
			wp_send_json_error( array(
				'message' => __( 'The name field is required.', 'ninja-tables' )
			), 423 );
		}

		$postId = intval( $_REQUEST['tableId'] );

		$attributes = array(
			'post_title'   => sanitize_text_field( $_REQUEST['post_title'] ),
			'post_content' => wp_kses_post( $_REQUEST['post_content'] ),
			'post_type'    => $this->cpt_name,
			'post_status'  => 'publish'
		);

		if ( ! $postId ) {
			$postId = wp_insert_post( $attributes );

			wp_send_json( array(
				'message'  => __( 'Successfully added table.', 'ninja-tables' ),
				'table_id' => $postId
			), 200 );
		} else {
			$attributes['ID'] = $postId;
			wp_update_post( $attributes );

			wp_send_json( array(
				'message'  => __( 'Successfully updated table.',
					'ninja-tables' ),
				'table_id' => $postId
			), 200 );
		}
	}

	public function importTable() {
		$format = $_REQUEST['format'];

		if ( $format == 'csv' ) {
			$this->uploadTableCsv();
		} elseif ( $format == 'json' ) {
			$this->uploadTableJson();
		} elseif ( $format == 'ninjaJson' ) {
			$this->uploadTableNinjaJson();
		}

		wp_send_json( array(
			'message' => __( 'No appropriate driver found for the import format.',
				'ninja-tables' )
		), 423 );
	}


	public function saveCustomCSS() {
		$tableId = intval( $_REQUEST['table_id'] );
		$css     = $_REQUEST['custom_css'];
		$css     = wp_strip_all_tags( $css );
		update_post_meta( $tableId, '_ninja_tables_custom_css', $css );

		wp_send_json_success( array(
			'message' => 'Custom CSS successfully saved'
		), 200 );
	}

	private function tablePressImport() {
		try {
			$tableId = intval( $_REQUEST['tableId'] );

			$table = get_post( $tableId );
			update_post_meta( $tableId, '_imported_to_ninja_table', 'yes' );
			$ninjaTableId = $this->createTable( array(
				'post_author'  => intval( $table->post_author ),
				'post_title'   => sanitize_text_field( '[Table Press] ' . $table->post_title ),
				'post_content' => wp_kses_post( $table->post_excerpt ),
				'post_status'  => $table->post_status,
				'post_type'    => $this->cpt_name,
			) );

			$rows = json_decode( $table->post_content, true );

			$tableSettings = get_post_meta( $table->ID, '_tablepress_table_options', true );

			$tableSettings = json_decode( $tableSettings, true );

			if ( $tableSettings['table_head'] ) {
				$header    = [];
				$headerRow = array_values( array_shift( $rows ) );
				foreach ( $headerRow as $index => $item ) {
					$header[ 'ninja_column_' . ( $index + 1 ) ] = $item;
				}
			} else {
				$header      = array();
				$columnCount = count( array_pop( array_reverse( $rows ) ) );

				for ( $i = 0; $i < $columnCount; $i ++ ) {
					$headerName           = 'Ninja Column ' . ( $i + 1 );
					$headerKey            = 'ninja_column_' . ( $i + 1 );
					$header[ $headerKey ] = $headerName;
				}
			}

			$rows = array_reverse( $rows );

			$this->storeTableConfigWhenImporting( $ninjaTableId, $header );

			$this->insertDataToTable( $ninjaTableId, $rows, $header );

			$message = __( 'Successfully imported '
			               . $table->post_title .
			               ' table from Table Press Plugin. Please go to all tables and review your table.'
			);
		} catch ( Exception $exception ) {
			$message = __( 'Sorry, we could not import the table.', 'ninja-tables' );
		}

		wp_send_json( array(
			'message' => $message
		), 200 );
	}

	private function getTablesFromPlugin() {
		$plugin       = sanitize_text_field( $_REQUEST['plugin'] );
		$libraryClass = false;

		if ( $plugin == 'UltimateTables' ) {
			$libraryClass = new NinjaTablesUltimateTableMigration();
		} elseif ( $plugin == 'TablePress' ) {
			$libraryClass = new NinjaTablesTablePressMigration();
		} elseif ( $plugin == 'supsystic' ) {
			$libraryClass = new \NinjaTables\Classes\NinjaTablesSupsysticTableMigration();
		} else {
			return false;
		}
		$tables = $libraryClass->getTables();

		wp_send_json( array(
			'tables' => $tables
		), 200 );
	}


	private function importTableFromPlugin() {
		$plugin  = esc_attr( $_REQUEST['plugin'] );
		$tableId = intval( $_REQUEST['tableId'] );

		if ( $plugin == 'UltimateTables' ) {
			$libraryClass = new NinjaTablesUltimateTableMigration();
		} elseif ( $plugin == 'TablePress' ) {
			$libraryClass = new NinjaTablesTablePressMigration();
		} elseif ( $plugin == 'supsystic' ) {
			$libraryClass = new \NinjaTables\Classes\NinjaTablesSupsysticTableMigration();
		} else {
			return false;
		}

		$tableId = $libraryClass->migrateTable( $tableId );
		if ( is_wp_error( $tableId ) ) {
			wp_send_json_error( array(
				'message' => $tableId->get_error_message()
			), 423 );
		}

		$message = __(
			'Successfully imported. Please go to all tables and review your newly imported table.',
			'ninja-tables'
		);

		wp_send_json_success( array(
			'message' => $message,
			'tableId' => $tableId
		), 200 );
	}

	private function formatHeader( $header ) {
		$data = array();

		$column_counter = 1;

		foreach ( $header as $item ) {
			$item = trim( strip_tags( $item ) );

			// We'll slugify only if item is printable characters.
			// Otherwise we'll generate custom key for the item.
			// Printable chars as in ASCII printable chars.
			// Ref: http://www.catonmat.net/blog/my-favorite-regex/
			$key = ! preg_match( '/[^ -~]/', $item ) ? $this->url_slug( $item ) : null;

			$key = sanitize_title( $key, 'ninja_column_' . $column_counter );

			$counter = 1;
			while ( isset( $data[ $key ] ) ) {
				$key .= '_' . $counter;
				$counter ++;
			}
			$data[ $key ] = $item;

			$column_counter ++;
		}

		return $data;
	}

	private function uploadTableCsv() {
		$tmpName = $_FILES['file']['tmp_name'];

		$reader = \League\Csv\Reader::createFromPath( $tmpName )->fetchAll();

		$header = array_shift( $reader );
		$reader = array_reverse( $reader );

		foreach ( $reader as &$item ) {
			// We have to convert everything to utf-8
			foreach ( $item as &$entry ) {
				$entry = mb_convert_encoding( $entry, 'UTF-8' );
			}
		}

		$tableId = $this->createTable();

		$header = $this->formatHeader( $header );

		$this->storeTableConfigWhenImporting( $tableId, $header );

		$this->insertDataToTable( $tableId, $reader, $header );

		wp_send_json( array(
			'message' => __( 'Successfully added a table.', 'ninja-tables' ),
			'tableId' => $tableId
		) );
	}

	private function uploadTableJson() {
		$tableId = $this->createTable();

		$tmpName = $_FILES['file']['tmp_name'];

		$content = json_decode( file_get_contents( $tmpName ), true );

		$header = array_keys( array_pop( array_reverse( $content ) ) );

		$this->storeTableConfigWhenImporting( $tableId, $header );

		$this->insertDataToTable( $tableId, $content, $header );

		wp_send_json( array(
			'message' => __( 'Successfully added a table.', 'ninja-tables' ),
			'tableId' => $tableId
		) );
	}

	private function uploadTableNinjaJson() {
		$tmpName = $_FILES['file']['tmp_name'];

		$content = json_decode( file_get_contents( $tmpName ), true );

		// validation
		if ( ! $content['post'] || ! $content['columns'] || ! $content['settings'] ) {
			wp_send_json( array(
				'message' => __( 'You have a faulty JSON file. Please export a new one.',
					'ninja-tables' )
			), 423 );
		}

		$tableAttributes = array(
			'post_title'   => sanitize_title( $content['post']['post_title'] ),
			'post_content' => wp_kses_post( $content['post']['post_content'] ),
			'post_type'    => $this->cpt_name,
			'post_status'  => 'publish'
		);

		$tableId = $this->createTable( $tableAttributes );

		update_post_meta( $tableId, '_ninja_table_columns', $content['columns'] );

		update_post_meta( $tableId, '_ninja_table_settings', $content['settings'] );

		if ( $rows = $content['rows'] ) {
			$header = [];

			foreach ( $content['columns'] as $column ) {
				$header[ $column['key'] ] = $column['name'];
			}

			$this->insertDataToTable( $tableId, $rows, $header );
		}

		wp_send_json( array(
			'message' => __( 'Successfully added a table.', 'ninja-tables' ),
			'tableId' => $tableId
		) );
	}

	private function createTable( $data = null ) {
		return wp_insert_post( $data
			? $data
			: array(
				'post_title'   => __( 'Temporary table name', 'ninja-tables' ),
				'post_content' => __( 'Temporary table description',
					'ninja-tables' ),
				'post_type'    => $this->cpt_name,
				'post_status'  => 'publish'
			) );
	}

	private function storeTableConfigWhenImporting( $tableId, $header ) {
		// ninja_table_columns
		$ninjaTableColumns = array();

		foreach ( $header as $key => $name ) {
			$ninjaTableColumns[] = array(
				'key'         => $key,
				'name'        => $name,
				'breakpoints' => ''
			);
		}

		update_post_meta( $tableId, '_ninja_table_columns', $ninjaTableColumns );

		// ninja_table_settings
		$ninjaTableSettings = ninja_table_get_table_settings( $tableId, 'admin' );

		update_post_meta( $tableId, '_ninja_table_settings', $ninjaTableSettings );

		ninjaTablesClearTableDataCache( $tableId );
	}

	private function insertDataToTable( $tableId, $values, $header ) {
		$header      = array_keys( $header );
		$time        = current_time( 'mysql' );
		$headerCount = count( $header );

		foreach ( $values as $item ) {
			if ( $headerCount == count( $item ) ) {
				$itemTemp = array_combine( $header, $item );
			} else {
				// The item can have less/more entry than the header has.
				// We have to ensure that the header and values match.
				$itemTemp = array_combine(
					$header,
					// We'll get the appropriate values by merging Array1 & Array2
					array_merge(
					// Array1 = Only the entries that the header has.
						array_intersect_key( $item, array_fill_keys( array_values( $header ), null ) ),
						// Array2 = The remaining header entries will be blank.
						array_fill_keys( array_diff( array_values( $header ), array_keys( $item ) ), null )
					)
				);
			}

			$data = array(
				'table_id'   => $tableId,
				'attribute'  => 'value',
				'value'      => json_encode( $itemTemp ),
				'created_at' => $time,
				'updated_at' => $time
			);

			ninja_tables_DbTable()->insert( $data );
		}
	}

	public function getTableSettings() {
		$tableID      = intval( $_REQUEST['table_id'] );
		$table        = get_post( $tableID );
		$tableColumns = ninja_table_get_table_columns( $tableID, 'admin' );

		$tableSettings     = ninja_table_get_table_settings( $tableID, 'admin' );
		$table->custom_css = get_post_meta( $tableID, '_ninja_tables_custom_css', true );

		wp_send_json( array(
			'columns'     => $tableColumns,
			'settings'    => $tableSettings,
			'table'       => $table,
			'preview_url' => site_url( '?ninjatable_preview=' . $tableID ),
		), 200 );
	}

	public function updateTableSettings() {
		$tableId = intval( $_REQUEST['table_id'] );

		$tableColumns = array();

		if ( isset( $_REQUEST['columns'] ) ) {
			$rawColumns = $_REQUEST['columns'];
			if ( $rawColumns && is_array( $rawColumns ) ) {
				foreach ( $rawColumns as $column ) {
					foreach ( $column as $column_index => $column_value ) {
						if ( $column_index == 'header_html_content' || $column_index == 'selections' ) {
							$column[ $column_index ] = wp_kses_post( $column_value );
						} else {
							$column[ $column_index ] = sanitize_text_field( $column_value );
						}
					}
					$tableColumns[] = $column;
				}
				update_post_meta( $tableId, '_ninja_table_columns', $tableColumns );
			}
		}

		$formattedTablePreference = array();

		if ( isset( $_REQUEST['table_settings'] ) ) {
			$tablePreference = $_REQUEST['table_settings'];
			if ( $tablePreference && is_array( $tablePreference ) ) {
				foreach ( $tablePreference as $key => $tab_pref ) {
					if ( $tab_pref == 'false' ) {
						$tab_pref = false;
					}

					if ( $tab_pref == 'true' ) {
						$tab_pref = true;
					}

					if ( is_array( $tab_pref ) ) {
						$tab_pref = array_map( 'sanitize_text_field', $tab_pref );
					} else {
						$tab_pref = sanitize_text_field( $tab_pref );
					}

					$formattedTablePreference[ $key ] = $tab_pref;
				}

				update_post_meta( $tableId, '_ninja_table_settings', $formattedTablePreference );
			}
		}

		ninjaTablesClearTableDataCache( $tableId );

		wp_send_json( array(
			'message'  => __( 'Successfully updated configuration.', 'ninja-tables' ),
			'columns'  => $tableColumns,
			'settings' => $formattedTablePreference
		), 200 );
	}

	public function getTable() {
		$tableId = intval( $_REQUEST['id'] );
		$table   = get_post( $tableId );

		wp_send_json( array(
			'data' => $table
		), 200 );
	}

	public function deleteTable() {
		$tableId = intval( $_REQUEST['table_id'] );

		if ( get_post_type( $tableId ) != $this->cpt_name ) {
			wp_send_json( array(
				'message' => __( 'Invalid Table to Delete', 'ninja-tables' )
			), 300 );
		}


		wp_delete_post( $tableId, true );
		// Delete the post metas
		delete_post_meta( $tableId, '_ninja_table_columns' );
		delete_post_meta( $tableId, '_ninja_table_settings' );
		delete_post_meta( $tableId, '_ninja_table_cache_object' );
		// now delete the data
		try {
			ninja_tables_DbTable()->where( 'table_id', $tableId )->delete();
		} catch ( Exception $e ) {
			//
		}

		wp_send_json( array(
			'message' => __( 'Successfully deleted the table.', 'ninja-tables' )
		), 200 );
	}

	public function getTableData() {
		$perPage = intval( $_REQUEST['per_page'] ) ?: 10;

		$currentPage = isset( $_GET['page'] ) ? intval( $_GET['page'] ) : 1;

		$skip = $perPage * ( $currentPage - 1 );

		$tableId = intval( $_REQUEST['table_id'] );

		$search = esc_attr( $_REQUEST['search'] );

		list( $orderByField, $orderByType ) = $this->getTableSortingParams( $tableId );

		$query = ninja_tables_DbTable()->where( 'table_id', $tableId );

		if ( $search ) {
			$query->search( $search, array( 'value' ) );
		}

		$data = $query->take( $perPage )
		              ->skip( $skip )
		              ->orderBy( $orderByField, $orderByType )
		              ->get();

		$total = ninja_tables_DbTable()->where( 'table_id', $tableId )->count();

		$response = array();

		foreach ( $data as $item ) {
			$response[] = array(
				'id'       => $item->id,
				'position' => property_exists( $item, 'position' ) ? $item->position : null,
				'values'   => json_decode( $item->value, true )
			);
		}

		wp_send_json( array(
			'total'        => $total,
			'per_page'     => $perPage,
			'current_page' => $currentPage,
			'last_page'    => ceil( $total / $perPage ),
			'data'         => $response
		), 200 );
	}

	/**
	 * Get the order by field and order by type values.
	 *
	 * @param        $tableId
	 * @param  null  $tableSettings
	 *
	 * @return array
	 */
	protected function getTableSortingParams( $tableId, $tableSettings = null ) {
		$tableSettings = $tableSettings ?: ninja_table_get_table_settings( $tableId, 'admin' );

		$orderByField = 'id';
		$orderByType  = 'DESC';

		if ( isset( $tableSettings['sorting_type'] ) ) {
			if ( $tableSettings['sorting_type'] === 'manual_sort' ) {
			    $this->migrateDatabaseIfNeeded();
				$orderByField = 'position';
				$orderByType  = 'ASC';
			} elseif ( $tableSettings['sorting_type'] === 'by_created_at' ) {
				$orderByField = 'id';
				if ( $tableSettings['default_sorting'] === 'new_first' ) {
					$orderByType = 'DESC';
				} else {
					$orderByType = 'ASC';
				}
			}
		}

		return [ $orderByField, $orderByType ];
	}

	public function storeData() {
		$tableId      = intval( $_REQUEST['table_id'] );
		$row          = $_REQUEST['row'];
		$formattedRow = array();

		foreach ( $row as $key => $item ) {
			$formattedRow[ $key ] = wp_unslash( $item );
		}

		$attributes = array(
			'table_id'   => $tableId,
			'attribute'  => 'value',
			'value'      => json_encode( $formattedRow, true ),
			'updated_at' => date( 'Y-m-d H:i:s' )
		);

		if ( $id = intval( $_REQUEST['id'] ) ) {
			ninja_tables_DbTable()->where( 'id', $id )->update( $attributes );
		} else {
			$attributes['created_at'] = date( 'Y-m-d H:i:s' );

			$attributes = apply_filters( 'ninja_tables_item_attributes', $attributes );

			$id = $insertId = ninja_tables_DbTable()->insert( $attributes );
		}

		$item = ninja_tables_DbTable()->find( $id );

		ninjaTablesClearTableDataCache( $tableId );

		wp_send_json( array(
			'message' => __( 'Successfully saved the data.', 'ninja-tables' ),
			'item'    => array(
				'id'       => $item->id,
				'values'   => $formattedRow,
				'row'      => json_decode( $item->value ),
				'position' => property_exists( $item, 'position' ) ? $item->position : null
			)
		), 200 );
	}

	public function deleteData() {
		$tableId = intval( $_REQUEST['table_id'] );

		$id = $_REQUEST['id'];

		$ids = is_array( $id ) ? $id : array( $id );

		$ids = array_map( function ( $item ) {
			return intval( $item );
		}, $ids );

		ninja_tables_DbTable()->where( 'table_id', $tableId )->whereIn( 'id', $ids )->delete();

		ninjaTablesClearTableDataCache( $tableId );

		wp_send_json( array(
			'message' => __( 'Successfully deleted data.', 'ninja-tables' )
		), 200 );
	}

	public function uploadData() {
		$tableId = intval( $_REQUEST['table_id'] );
		$tmpName = $_FILES['file']['tmp_name'];

		$reader = \League\Csv\Reader::createFromPath( $tmpName )->fetchAll();

		$csvHeader = array_shift( $reader );
		$csvHeader = array_map( 'esc_attr', $csvHeader );

		$config = get_post_meta( $tableId, '_ninja_table_columns', true );
		if ( ! $config ) {
			wp_send_json( array(
				'message' => __( 'Please set table configuration.', 'ninja-tables' )
			), 423 );
		}

		$header = array();

		foreach ( $csvHeader as $item ) {
			foreach ( $config as $column ) {
				$item = esc_attr( $item );
				if ( $item == $column['key'] || $item == $column['name'] ) {
					$header[] = $column['key'];
				}
			}
		}

		if ( count( $header ) != count( $config ) ) {
			wp_send_json( array(
				'message' => __( 'Please use the provided CSV header structure.', 'ninja-tables' )
			), 423 );
		}

		$data = array();
		$time = current_time( 'mysql' );

		foreach ( $reader as $item ) {
			// If item has any ascii entry we'll convert it to utf-8
			foreach ( $item as &$entry ) {
				$entry = mb_convert_encoding( $entry, 'UTF-8' );
			}

			$itemTemp = array_combine( $header, $item );

			array_push( $data, array(
				'table_id'   => $tableId,
				'attribute'  => 'value',
				'value'      => json_encode( $itemTemp ),
				'created_at' => $time,
				'updated_at' => $time
			) );
		}

		$replace = $_REQUEST['replace'] === 'true';

		if ( $replace ) {
			ninja_tables_DbTable()->where( 'table_id', $tableId )->delete();
		}

		$data = apply_filters( 'ninja_tables_import_table_data', $data, $tableId );

		ninja_tables_DbTable()->batch_insert( $data );

		ninjaTablesClearTableDataCache( $tableId );

		wp_send_json( array(
			'message' => __( 'Successfully uploaded data.', 'ninja-tables' )
		) );
	}

	public function exportData() {
		$format = esc_attr( $_REQUEST['format'] );

		$tableId = intval( $_REQUEST['table_id'] );

		$tableTitle = get_the_title( $tableId );

		$fileName = sanitize_title( $tableTitle, date( 'Y-m-d-H-i-s' ), 'preview' );

		$tableColumns = ninja_table_get_table_columns( $tableId, 'admin' );

		$tableSettings = ninja_table_get_table_settings( $tableId, 'admin' );

		list( $orderByField, $orderByType ) = $this->getTableSortingParams( $tableId, $tableSettings );

		$data = ninja_tables_DbTable()->where( 'table_id', $tableId )->orderBy( $orderByField, $orderByType )->get();

		if ( $format == 'csv' ) {

			$header = array();

			foreach ( $tableColumns as $item ) {
				$header[ $item['key'] ] = $item['name'];
			}

			$exportData = array();

			foreach ( $data as $item ) {
				$temp = array();
				$item = json_decode( $item->value, true );

				foreach ( $header as $accessor => $name ) {
					$temp[] = $item[ $accessor ];
				}

				array_push( $exportData, $temp );
			}

			$this->exportAsCSV( array_values( $header ), $exportData, $fileName . '.csv' );
		} elseif ( $format == 'json' ) {
			$table = get_post( $tableId );

			$tableItems = array_map( function ( $item ) {
				return json_decode( $item->value, true );
			}, $data );

			$exportData = array(
				'post'     => $table,
				'columns'  => $tableColumns,
				'settings' => $tableSettings,
				'rows'     => $tableItems
			);

			$this->exportAsJSON( $exportData, $fileName . '.json' );
		}
	}

	private function exportAsCSV( $header, $data, $fileName = null ) {
		$fileName = $fileName ?: 'export-data-' . date( 'd-m-Y' );

		$writer = \League\Csv\Writer::createFromFileObject( new SplTempFileObject() );
		$writer->setDelimiter( "," );
		$writer->setNewline( "\r\n" );
		$writer->insertOne( $header );
		$writer->insertAll( $data );
		$writer->output( $fileName . '.csv' );
		die();
	}

	private function exportAsJSON( $data, $fileName = null ) {
		$fileName = $fileName ?: 'export-data-' . date( 'd-m-Y' ) . '.json';

		header( 'Content-disposition: attachment; filename=' . $fileName );

		header( 'Content-type: application/json' );

		echo json_encode( $data );

		die();
	}

	public function add_tabales_to_editor() {
		if ( user_can_richedit() ) {
			$pages_with_editor_button = array( 'post.php', 'post-new.php' );
			foreach ( $pages_with_editor_button as $editor_page ) {
				add_action( "load-{$editor_page}", array( $this, 'init_ninja_mce_buttons' ) );
			}
		}
	}

	public function init_ninja_mce_buttons() {
		add_filter( "mce_external_plugins", array( $this, 'ninja_table_add_button' ) );
		add_filter( 'mce_buttons', array( $this, 'ninja_table_register_button' ) );
		add_action( 'admin_footer', array( $this, 'pushNinjaTablesToEditorFooter' ) );
	}

	public function pushNinjaTablesToEditorFooter() {
		$tables = $this->getAllTablesForMce();
		?>
        <script type="text/javascript">
            window.ninja_tables_tiny_mce = {
                label: '<?php _e( 'Select a Table to insert', 'ninja-tables' ) ?>',
                title: '<?php _e( 'Insert Ninja Tables Shortcode', 'ninja-tables' ) ?>',
                select_error: '<?php _e( 'Please select a table' ); ?>',
                insert_text: '<?php _e( 'Insert Shortcode', 'ninja-tables' ); ?>',
                tables: <?php echo json_encode( $tables );?>
            }
        </script>
		<?php
	}

	private function getAllTablesForMce() {
		$args = array(
			'posts_per_page' => - 1,
			'orderby'        => 'date',
			'order'          => 'DESC',
			'post_type'      => $this->cpt_name,
			'post_status'    => 'any'
		);

		$tables      = get_posts( $args );
		$formatted   = array();
		$formatted[] = array(
			'text'  => __( 'Select a Table', 'ninja-tables' ),
			'value' => ''
		);

		foreach ( $tables as $table ) {
			$formatted[] = array(
				'text'  => $table->post_title,
				'value' => $table->ID
			);
		}

		return $formatted;
	}

	/**
	 * add a button to Tiny MCE editor
	 *
	 * @param $plugin_array
	 *
	 * @return mixed
	 */
	public function ninja_table_add_button( $plugin_array ) {
		$plugin_array['ninja_table'] = NINJA_TABLES_DIR_URL . 'assets/js/ninja-table-tinymce-button.js';

		return $plugin_array;
	}

	/**
	 * register a button to Tiny MCE editor
	 *
	 * @param $buttons
	 *
	 * @return mixed
	 */
	public function ninja_table_register_button( $buttons ) {
		array_push( $buttons, 'ninja_table' );

		return $buttons;
	}

	public function dismissPluginSuggest() {
		update_option( '_ninja_tables_plugin_suggest_dismiss', time() );
	}

	private function url_slug( $str, $options = array() ) {
		// Make sure string is in UTF-8 and strip invalid UTF-8 characters
		$str = mb_convert_encoding( (string) $str, 'UTF-8', mb_list_encodings() );

		$defaults = array(
			'delimiter'     => '_',
			'limit'         => null,
			'lowercase'     => true,
			'replacements'  => array(),
			'transliterate' => true,
		);

		// Merge options
		$options = array_merge( $defaults, $options );

		$char_map = array(
			// Latin
			'À' => 'A',
			'Á' => 'A',
			'Â' => 'A',
			'Ã' => 'A',
			'Ä' => 'A',
			'Å' => 'A',
			'Æ' => 'AE',
			'Ç' => 'C',
			'È' => 'E',
			'É' => 'E',
			'Ê' => 'E',
			'Ë' => 'E',
			'Ì' => 'I',
			'Í' => 'I',
			'Î' => 'I',
			'Ï' => 'I',
			'Ð' => 'D',
			'Ñ' => 'N',
			'Ò' => 'O',
			'Ó' => 'O',
			'Ô' => 'O',
			'Õ' => 'O',
			'Ö' => 'O',
			'Ő' => 'O',
			'Ø' => 'O',
			'Ù' => 'U',
			'Ú' => 'U',
			'Û' => 'U',
			'Ü' => 'U',
			'Ű' => 'U',
			'Ý' => 'Y',
			'Þ' => 'TH',
			'ß' => 'ss',
			'à' => 'a',
			'á' => 'a',
			'â' => 'a',
			'ã' => 'a',
			'ä' => 'a',
			'å' => 'a',
			'æ' => 'ae',
			'ç' => 'c',
			'è' => 'e',
			'é' => 'e',
			'ê' => 'e',
			'ë' => 'e',
			'ì' => 'i',
			'í' => 'i',
			'î' => 'i',
			'ï' => 'i',
			'ð' => 'd',
			'ñ' => 'n',
			'ò' => 'o',
			'ó' => 'o',
			'ô' => 'o',
			'õ' => 'o',
			'ö' => 'o',
			'ő' => 'o',
			'ø' => 'o',
			'ù' => 'u',
			'ú' => 'u',
			'û' => 'u',
			'ü' => 'u',
			'ű' => 'u',
			'ý' => 'y',
			'þ' => 'th',
			'ÿ' => 'y',
			// Latin symbols
			'©' => '(c)',
			// Greek
			'Α' => 'A',
			'Β' => 'B',
			'Γ' => 'G',
			'Δ' => 'D',
			'Ε' => 'E',
			'Ζ' => 'Z',
			'Η' => 'H',
			'Θ' => '8',
			'Ι' => 'I',
			'Κ' => 'K',
			'Λ' => 'L',
			'Μ' => 'M',
			'Ν' => 'N',
			'Ξ' => '3',
			'Ο' => 'O',
			'Π' => 'P',
			'Ρ' => 'R',
			'Σ' => 'S',
			'Τ' => 'T',
			'Υ' => 'Y',
			'Φ' => 'F',
			'Χ' => 'X',
			'Ψ' => 'PS',
			'Ω' => 'W',
			'Ά' => 'A',
			'Έ' => 'E',
			'Ί' => 'I',
			'Ό' => 'O',
			'Ύ' => 'Y',
			'Ή' => 'H',
			'Ώ' => 'W',
			'Ϊ' => 'I',
			'Ϋ' => 'Y',
			'α' => 'a',
			'β' => 'b',
			'γ' => 'g',
			'δ' => 'd',
			'ε' => 'e',
			'ζ' => 'z',
			'η' => 'h',
			'θ' => '8',
			'ι' => 'i',
			'κ' => 'k',
			'λ' => 'l',
			'μ' => 'm',
			'ν' => 'n',
			'ξ' => '3',
			'ο' => 'o',
			'π' => 'p',
			'ρ' => 'r',
			'σ' => 's',
			'τ' => 't',
			'υ' => 'y',
			'φ' => 'f',
			'χ' => 'x',
			'ψ' => 'ps',
			'ω' => 'w',
			'ά' => 'a',
			'έ' => 'e',
			'ί' => 'i',
			'ό' => 'o',
			'ύ' => 'y',
			'ή' => 'h',
			'ώ' => 'w',
			'ς' => 's',
			'ϊ' => 'i',
			'ΰ' => 'y',
			'ϋ' => 'y',
			'ΐ' => 'i',
			// Turkish
			'Ş' => 'S',
			'İ' => 'I',
			'Ç' => 'C',
			'Ü' => 'U',
			'Ö' => 'O',
			'Ğ' => 'G',
			'ş' => 's',
			'ı' => 'i',
			'ç' => 'c',
			'ü' => 'u',
			'ö' => 'o',
			'ğ' => 'g',
			// Russian
			'А' => 'A',
			'Б' => 'B',
			'В' => 'V',
			'Г' => 'G',
			'Д' => 'D',
			'Е' => 'E',
			'Ё' => 'Yo',
			'Ж' => 'Zh',
			'З' => 'Z',
			'И' => 'I',
			'Й' => 'J',
			'К' => 'K',
			'Л' => 'L',
			'М' => 'M',
			'Н' => 'N',
			'О' => 'O',
			'П' => 'P',
			'Р' => 'R',
			'С' => 'S',
			'Т' => 'T',
			'У' => 'U',
			'Ф' => 'F',
			'Х' => 'H',
			'Ц' => 'C',
			'Ч' => 'Ch',
			'Ш' => 'Sh',
			'Щ' => 'Sh',
			'Ъ' => '',
			'Ы' => 'Y',
			'Ь' => '',
			'Э' => 'E',
			'Ю' => 'Yu',
			'Я' => 'Ya',
			'а' => 'a',
			'б' => 'b',
			'в' => 'v',
			'г' => 'g',
			'д' => 'd',
			'е' => 'e',
			'ё' => 'yo',
			'ж' => 'zh',
			'з' => 'z',
			'и' => 'i',
			'й' => 'j',
			'к' => 'k',
			'л' => 'l',
			'м' => 'm',
			'н' => 'n',
			'о' => 'o',
			'п' => 'p',
			'р' => 'r',
			'с' => 's',
			'т' => 't',
			'у' => 'u',
			'ф' => 'f',
			'х' => 'h',
			'ц' => 'c',
			'ч' => 'ch',
			'ш' => 'sh',
			'щ' => 'sh',
			'ъ' => '',
			'ы' => 'y',
			'ь' => '',
			'э' => 'e',
			'ю' => 'yu',
			'я' => 'ya',
			// Ukrainian
			'Є' => 'Ye',
			'І' => 'I',
			'Ї' => 'Yi',
			'Ґ' => 'G',
			'є' => 'ye',
			'і' => 'i',
			'ї' => 'yi',
			'ґ' => 'g',
			// Czech
			'Č' => 'C',
			'Ď' => 'D',
			'Ě' => 'E',
			'Ň' => 'N',
			'Ř' => 'R',
			'Š' => 'S',
			'Ť' => 'T',
			'Ů' => 'U',
			'Ž' => 'Z',
			'č' => 'c',
			'ď' => 'd',
			'ě' => 'e',
			'ň' => 'n',
			'ř' => 'r',
			'š' => 's',
			'ť' => 't',
			'ů' => 'u',
			'ž' => 'z',
			// Polish
			'Ą' => 'A',
			'Ć' => 'C',
			'Ę' => 'e',
			'Ł' => 'L',
			'Ń' => 'N',
			'Ó' => 'o',
			'Ś' => 'S',
			'Ź' => 'Z',
			'Ż' => 'Z',
			'ą' => 'a',
			'ć' => 'c',
			'ę' => 'e',
			'ł' => 'l',
			'ń' => 'n',
			'ó' => 'o',
			'ś' => 's',
			'ź' => 'z',
			'ż' => 'z',
			// Latvian
			'Ā' => 'A',
			'Č' => 'C',
			'Ē' => 'E',
			'Ģ' => 'G',
			'Ī' => 'i',
			'Ķ' => 'k',
			'Ļ' => 'L',
			'Ņ' => 'N',
			'Š' => 'S',
			'Ū' => 'u',
			'Ž' => 'Z',
			'ā' => 'a',
			'č' => 'c',
			'ē' => 'e',
			'ģ' => 'g',
			'ī' => 'i',
			'ķ' => 'k',
			'ļ' => 'l',
			'ņ' => 'n',
			'š' => 's',
			'ū' => 'u',
			'ž' => 'z',
		);

		// Make custom replacements
		$str = preg_replace( array_keys( $options['replacements'] ), $options['replacements'], $str );

		// Transliterate characters to ASCII
		if ( $options['transliterate'] ) {
			$str = str_replace( array_keys( $char_map ), $char_map, $str );
		}

		// Replace non-alphanumeric characters with our delimiter
		$str = preg_replace( '/[^\p{L}\p{Nd}]+/u', $options['delimiter'], $str );

		// Remove duplicate delimiters
		$str = preg_replace( '/(' . preg_quote( $options['delimiter'], '/' ) . '){2,}/', '$1', $str );

		// Truncate slug to max. characters
		$str = mb_substr( $str, 0, ( $options['limit'] ? $options['limit'] : mb_strlen( $str, 'UTF-8' ) ), 'UTF-8' );

		// Remove delimiter from ends
		$str = trim( $str, $options['delimiter'] );

		return $options['lowercase'] ? mb_strtolower( $str, 'UTF-8' ) : $str;
	}

	/**
	 * Save a flag if the a post/page/cpt have [ninja_tables] shortcode
	 *
	 * @param int $post_id
	 *
	 * @return void
	 */
	public function saveNinjaTableFlagOnShortCode( $post_id ) {
		if ( isset( $_POST['post_content'] ) ) {
			$post_content = $_POST['post_content'];
		} else {
			$post         = get_post( $post_id );
			$post_content = $post->post_content;
		}
		if ( has_shortcode( $post_content, 'ninja_tables' ) ) {
			update_post_meta( $post_id, '_has_ninja_tables', 1 );
		} elseif ( get_post_meta( $post_id, '_has_ninja_tables', true ) ) {
			update_post_meta( $post_id, '_has_ninja_tables', 0 );
		}
	}

	public function duplicateTable() {
		$oldPostId = intval( $_REQUEST['tableId'] );

		$post = get_post( $oldPostId );

		// Duplicate table itself.
		$attributes = array(
			'post_title'   => $post->post_title . '( Duplicate )',
			'post_content' => $post->post_content,
			'post_type'    => $post->post_type,
			'post_status'  => 'publish'
		);

		$newPostId = wp_insert_post( $attributes );

		global $wpdb;

		// Duplicate table settings.
		$postMetaTable = $wpdb->prefix . 'postmeta';

		$sql = "INSERT INTO $postMetaTable (`post_id`, `meta_key`, `meta_value`)";
		$sql .= " SELECT $newPostId, `meta_key`, `meta_value` FROM $postMetaTable WHERE `post_id` = $oldPostId";

		$wpdb->query( $sql );

		// Duplicate table rows.
		$itemsTable = $wpdb->prefix . ninja_tables_db_table_name();

		$sql = "INSERT INTO $itemsTable (`position`, `table_id`, `attribute`, `value`, `created_at`, `updated_at`)";
		$sql .= " SELECT `position`, $newPostId, `attribute`, `value`, `created_at`, `updated_at` FROM $itemsTable";
		$sql .= " WHERE `table_id` = $oldPostId";

		$wpdb->query( $sql );

		wp_send_json_success( array(
			'message'  => __( 'Successfully duplicated table.', 'ninja-tables' ),
			'table_id' => $newPostId
		), 200 );
	}


	public function getAccessRoles() {
		$roles         = get_editable_roles();
		$formatted     = array();
		$excludedRoles = array( 'subscriber', 'administrator' );
		foreach ( $roles as $key => $role ) {
			if ( ! in_array( $key, $excludedRoles ) ) {
				$formatted[] = array(
					'name' => $role['name'],
					'key'  => $key
				);
			}
		}

		$capability = get_option( '_ninja_tables_permission' );

		if ( is_string( $capability ) ) {
			$capability = [];
		}

		wp_send_json( array(
			'capability' => $capability,
			'roles'      => $formatted
		), 200 );
	}

	public function getTablePreviewHtml() {
		// sleep(3);
		$tableId       = intval( $_REQUEST['table_id'] );
		$tableColumns  = ninja_table_get_table_columns( $tableId, 'public' );
		$tableSettings = ninja_table_get_table_settings( $tableId, 'public' );

		$formattedColumns = [];
		foreach ( $tableColumns as $index => $column ) {
			$formattedColumns[] = NinjaFooTable::getFormattedColumn( $column, $index, $tableSettings, true,
				'by_created_at' );
		}
		$formatted_data = ninjaTablesGetTablesDataByID( $tableId, $tableSettings['default_sorting'], true, 25 );
		echo self::loadView( 'public/views/table_inner_html', array(
			'table_columns' => $formattedColumns,
			'table_rows'    => $formatted_data
		) );
	}

	private static function loadView( $file, $data ) {
		$file = NINJA_TABLES_DIR_PATH . $file . '.php';
		ob_start();
		extract( $data );
		include $file;

		return ob_get_clean();
	}
	
	public function migrateDatabaseIfNeeded() {
		// If the database is already migrated for manual
		// sorting the option table would have a flag.
		$option = '_ninja_tables_sorting_migration';
		global $wpdb;
		$tableName = $wpdb->prefix.ninja_tables_db_table_name();

		$row = $wpdb->get_row( "SELECT * FROM $tableName" );
		
		if(!$row) {
		    return;
        }
        if(property_exists($row, 'position')) {
		    return;
        }
        
		// Update the databse to hold the sorting position number.
		$sql = "ALTER TABLE $tableName ADD COLUMN `position` INT(11) AFTER `id`;";

		$wpdb->query( $sql );
		// Keep a flag on the options table that the
		// db is migrated to use for manual sorting.
		add_option( $option, true );
	}
}
