<?php namespace NinjaTables\Classes;

/**
 * The file that defines the core plugin class
 *
 * A class definition that includes attributes and functions used across both the
 * public-facing side of the site and the admin area.
 *
 * @link       https://authlab.io
 * @since      1.0.0
 *
 * @package    Wp_table_data_press
 * @subpackage Wp_table_data_press/includes
 */
use NinjaTable\FrontEnd\NinjaTablePublic;

/**
 * The core plugin class.
 *
 * This is used to define internationalization, admin-specific hooks, and
 * public-facing site hooks.
 *
 * Also maintains the unique identifier of this plugin as well as the current
 * version of the plugin.
 *
 * @since      1.0.0
 * @package    ninja-tables
 * @subpackage ninja-tables/includes
 * @author     Shahjahan Jewel <cep.jewel@gmail.com>
 */
class NinjaTableClass {

	/**
	 * The loader that's responsible for maintaining and registering all hooks that power
	 * the plugin.
	 *
	 * @since    1.0.0
	 * @access   protected
	 * @var      NinjaTablesLoader    $loader    Maintains and registers all hooks for the plugin.
	 */
	protected $loader;

	/**
	 * The unique identifier of this plugin.
	 *
	 * @since    1.0.0
	 * @access   protected
	 * @var      string    $plugin_name    The string used to uniquely identify this plugin.
	 */
	protected $plugin_name;

	/**
	 * The current version of the plugin.
	 *
	 * @since    1.0.0
	 * @access   protected
	 * @var      string    $version    The current version of the plugin.
	 */
	protected $version;

	/**
	 * Define the core functionality of the plugin.
	 *
	 * Set the plugin name and the plugin version that can be used throughout the plugin.
	 * Load the dependencies, define the locale, and set the hooks for the admin area and
	 * the public-facing side of the site.
	 *
	 * @since    1.0.0
	 */
	public function __construct() {
		$this->plugin_name = 'ninja-tables';
		$this->version = NINJA_TABLES_VERSION;
		$this->load_dependencies();
		$this->set_locale();
		$this->define_admin_hooks();
		$this->define_public_hooks();
	}

	/**
	 * Load the required dependencies for this plugin.
	 * Include the following files that make up the plugin:
	 *
	 * - NinjaTablesLoader. Orchestrates the hooks of the plugin.
	 * - Wp_table_data_press_i18n. Defines internationalization functionality.
	 * - Wp_table_data_press_Admin. Defines all hooks for the admin area.
	 * - Wp_table_data_press_Public. Defines all hooks for the public side of the site.
	 *
	 * Create an instance of the loader which will be used to register the hooks
	 * with WordPress.
	 *
	 * @since    1.0.0
	 * @access   private
	 */
	private function load_dependencies() {
		
		/**
		 * The class responsible for orchestrating the actions and filters of the
		 * core plugin.
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/NinjaTablesLoader.php';

		/**
		 * The class responsible for defining internationalization functionality
		 * of the plugin.
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/NinjaTablesI18n.php';


		/**
		 * The class responsible for all global functions.
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/ninja_tables-global-functions.php';
		
		/**
		 * Include Libs
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/libs/autoload.php';

		/**
		 * Extorior Page
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/ProcessDemoPage.php';
		
		
		/**
		 * The class responsible for defining all actions that occur in the admin area.
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'admin/NinjaTablesAdmin.php';

		/**
		 * The class responsible for defining all actions that occur in the public-facing
		 * side of the site.
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'public/NinjaTablePublic.php';

		/**
		 * Load Tables Migration Class
		 */
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/NinjaTablesMigration.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/NinjaTablesUltimateTableMigration.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/NinjaTablesSupsysticTableMigration.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/NinjaTablesTablePressMigration.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/I18nStrings.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/ArrayHelper.php';
		require_once plugin_dir_path( dirname( __FILE__ ) ) . 'includes/libs/TableDrivers/NinjaFooTable.php';

		$this->loader = new NinjaTablesLoader();
	}

	/**
	 * Define the locale for this plugin for internationalization.
	 *
	 * Uses the NinjaTablesI18n class in order to set the domain and to register the hook
	 * with WordPress.
	 *
	 * @since    1.0.0
	 * @access   private
	 */
	private function set_locale() {
		$plugin_i18n = new NinjaTablesI18n();
		$this->loader->add_action( 'plugins_loaded', $plugin_i18n, 'load_plugin_textdomain' );
	}

	/**
	 * Register all of the hooks related to the admin area functionality
	 * of the plugin.
	 *
	 * @since    1.0.0
	 * @access   private
	 */
	private function define_admin_hooks() {

		$plugin_admin = new \NinjaTablesAdmin( $this->get_plugin_name(), $this->get_version() );
		$demoPage = new ProcessDemoPage();
		$this->loader->add_action( 'init', $plugin_admin, 'register_post_type' );
		$this->loader->add_action( 'admin_menu', $plugin_admin, 'add_menu' );
		
		$this->loader->add_action('save_post', $plugin_admin, 'saveNinjaTableFlagOnShortCode');
		
        $this->loader->add_action('wp_ajax_ninja_tables_ajax_actions',
            $plugin_admin,
            'ajax_routes'
        );
        $this->loader->add_action('init', $plugin_admin, 'add_tabales_to_editor');
        
        $this->loader->add_action('init', $demoPage, 'handleExteriorPages');

		add_action('admin_enqueue_scripts', function()
		{
			if(isset($_GET['page']) && $_GET['page'] == 'ninja_tables') {
				wp_enqueue_media();
			}
		});

		add_filter('pre_set_site_transient_update_plugins', function ($updates) {
			if (!empty($updates->response['ninja-tables-pro'])) {
				$updates->response['ninja-tables-pro/ninja-tables-pro.php'] = $updates->response['ninja-tables-pro'];
				unset($updates->response['ninja-tables-pro']);
			}
			return $updates;
		}, 999, 1);
		
	}

	/**
	 * Register all of the hooks related to the public-facing functionality
	 * of the plugin.
	 *
	 * @since    1.0.0
	 * @access   private
	 */
	private function define_public_hooks() {
		$plugin_public = new NinjaTablePublic( $this->get_plugin_name(), $this->get_version() );
		$this->loader->add_action('init', $plugin_public, 'register_table_render_functions');
		$this->loader->add_action('wp_enqueue_scripts', $plugin_public, 'enqueueNinjaTableScript', 100);
		
		$this->loader->add_action('wp_ajax_wp_ajax_ninja_tables_public_action',
			$plugin_public,
			'register_ajax_routes'
		);
		
		$this->loader->add_action('wp_ajax_nopriv_wp_ajax_ninja_tables_public_action',
			$plugin_public,
			'register_ajax_routes'
		);
		
		// run foo table
		$this->loader->add_action('ninja_tables-render-table-footable', 'NinjaTable\TableDrivers\NinjaFooTable', 'run');
		$this->loader->add_action('ninja_tables_inside_table_render', 'NinjaTable\TableDrivers\NinjaFooTable', 'getTableHTML', 10, 2);
		
	}

	/**
	 * Run the loader to execute all of the hooks with WordPress.
	 *
	 * @since    1.0.0
	 */
	public function run() {
		$this->loader->run();
	}

	/**
	 * The name of the plugin used to uniquely identify it within the context of
	 * WordPress and to define internationalization functionality.
	 *
	 * @since     1.0.0
	 * @return    string    The name of the plugin.
	 */
	public function get_plugin_name() {
		return $this->plugin_name;
	}

	/**
	 * The reference to the class that orchestrates the hooks with the plugin.
	 *
	 * @since     1.0.0
	 * @return    NinjaTablesLoader    Orchestrates the hooks of the plugin.
	 */
	public function get_loader() {
		return $this->loader;
	}

	/**
	 * Retrieve the version number of the plugin.
	 *
	 * @since     1.0.0
	 * @return    string    The version number of the plugin.
	 */
	public function get_version() {
		return $this->version;
	}
}