<?php namespace NinjaTable\TableDrivers;

use NinjaTables\Classes\ArrayHelper;

class NinjaFooTable {
	public static $version = NINJA_TABLES_VERSION;

	public static function run( $tableArray ) {
        global $ninja_table_instances;
        $tableInstance = 'ninja_table_instance_'.count($ninja_table_instances);
		$ninja_table_instances[] = $tableInstance;
		$styleSrc = NINJA_TABLES_DIR_URL . "assets/css/ninjatables-public.css";

		if ( is_rtl() ) {
			$styleSrc = NINJA_TABLES_DIR_URL . "assets/css/ninjatables-public-rtl.css";
		}

		wp_enqueue_style(
			'footable_styles',
			$styleSrc,
			array(),
			self::$version,
			'all'
		);

		if ( ! ArrayHelper::get( $tableArray, 'settings.table_color_type' ) ) {
			if ( ArrayHelper::get( $tableArray, 'settings.table_color' ) == 'ninja_table_custom_color' ) {
				$tableArray['settings']['table_color_type'] = 'custom_color';
			} else {
				$tableArray['settings']['table_color_type'] = 'pre_defined_color';
			}
		}

		$tableArray['table_instance_name'] = $tableInstance;

		self::enqueue_assets();
		
		self::render( $tableArray );

		
	}

	private static function enqueue_assets() {

		wp_enqueue_script( 'footable',
			NINJA_TABLES_PUBLIC_DIR_URL . "libs/footable/js/footable.min.js",
			array( 'jquery' ), '3.1.5', true );

		wp_enqueue_script( 'footable_init',
			NINJA_TABLES_DIR_URL . "assets/js/ninja-tables-footable." . NINJA_TABLES_ASSET_VERSION . ".js",
			array( 'footable' ), self::$version, true );

		wp_localize_script( 'footable_init', 'ninja_footables', array(
			'ajax_url' => admin_url( 'admin-ajax.php' ),
			'tables'   => array(),
			'i18n'     => array(
				'search_in'  => __( 'Search in', 'ninja-tables' ),
				'search'     => __( 'Search', 'ninja-tables' ),
				'empty_text' => __( 'No Result Found', 'ninja-tables' ),
			)
		) );
	}

	/**
	 * Set the table header colors.
	 *
	 * @param array  $tableArray
	 *
	 * @param string $extra_css
	 *
	 * @return void
	 */
	private static function addCustomColorCSS( $tableArray, $extra_css = '' ) {
		$colors        = false;
		$custom_css    = get_post_meta( $tableArray['table_id'], '_ninja_tables_custom_css', true );
		
		if ( ArrayHelper::get( $tableArray, 'settings.table_color_type' ) == 'custom_color' && defined('NINJATABLESPRO') ) {
			$colorSettings = $tableArray['settings'];
			$colors = array(
				'table_color_primary' => ArrayHelper::get($colorSettings, 'table_color_primary'),
				'table_color_secondary' => ArrayHelper::get($colorSettings, 'table_color_secondary'),
				'table_color_border' => ArrayHelper::get($colorSettings, 'table_color_border'),
				
				'table_search_color_primary' => ArrayHelper::get($colorSettings, 'table_search_color_primary'),
				'table_search_color_secondary' => ArrayHelper::get($colorSettings, 'table_search_color_secondary'),
				'table_search_color_border' => ArrayHelper::get($colorSettings, 'table_search_color_border'),

				'table_header_color_primary' => ArrayHelper::get($colorSettings, 'table_header_color_primary'),
				'table_color_header_secondary' => ArrayHelper::get($colorSettings, 'table_color_header_secondary'),
				'table_color_header_border' => ArrayHelper::get($colorSettings, 'table_color_header_border'),
				
				'alternate_color_status' => ArrayHelper::get($colorSettings, 'alternate_color_status'),
				
				'table_alt_color_primary' => ArrayHelper::get($colorSettings, 'table_alt_color_primary'),
				'table_alt_color_secondary' => ArrayHelper::get($colorSettings, 'table_alt_color_secondary'),
				'table_alt_color_hover' => ArrayHelper::get($colorSettings, 'table_alt_color_hover'),

				'table_alt_2_color_primary' => ArrayHelper::get($colorSettings, 'table_alt_2_color_primary'),
				'table_alt_2_color_secondary' => ArrayHelper::get($colorSettings, 'table_alt_2_color_secondary'),
				'table_alt_2_color_hover' => ArrayHelper::get($colorSettings, 'table_alt_2_color_hover'),
				
				'table_footer_bg' => ArrayHelper::get($colorSettings, 'table_footer_bg'),
				'table_footer_active' => ArrayHelper::get($colorSettings, 'table_footer_active'),
				'table_footer_border' => ArrayHelper::get($colorSettings, 'table_footer_border'),
			);
		}

		$custom_css .= $extra_css;
		
		if ( ! $colors && !$custom_css ) {
			return;
		}
		
		$css_prefix = '#footable_' . $tableArray['table_id'];
		add_action( 'wp_footer', function () use ( $custom_css, $colors, $css_prefix ) {
			include 'views/ninja_footable_css.php';
		} );
	}

	private static function render( $tableArray ) {
		extract( $tableArray );
		if ( ! count( $columns ) ) {
			return;
		}
		
		$renderType = ArrayHelper::get( $settings, 'render_type', 'ajax_table' );

		$formatted_columns = array();
		$sortingType       = ArrayHelper::get( $settings, 'sorting_type', 'by_created_at' );

		$globalSorting = (bool) ArrayHelper::get( $settings, 'column_sorting', false );

		$customCss = array();

		$columnContentCss = '';
		
		foreach ( $columns as $index => $column ) {
			if( $contentAlign = ArrayHelper::get( $column, 'contentAlign' ) ) {
				$columnContentCss .= '#footable_'.$tableArray['table_id'].' td.ninja_column_'.$index .' { text-align: '.$contentAlign.'; }';
            }
			$columnType    = self::getColumnType( $column );
			$cssColumnName = 'ninja_column_' . $index;
			$columnClasses = array( $cssColumnName );
			if ( isset( $column['classes'] ) ) {
				$userClasses   = explode( ' ', $column['classes'] );
				$columnClasses = array_unique( array_merge( $columnClasses, $userClasses ) );
			}
			$customCss[ $cssColumnName ] = array();
			if ( $columnWidth = ArrayHelper::get( $column, 'width' ) ) {
				$customCss[ $cssColumnName ]['width'] = $columnWidth . 'px';
			}
			if ( $textAlign = ArrayHelper::get( $column, 'textAlign' ) ) {
				$customCss[ $cssColumnName ]['textAlign'] = $textAlign;
			}
			$columnTitle = $column['name'];
			if ( ArrayHelper::get( $column, 'enable_html_content' ) == 'true' ) {
				if ( $columnContent = ArrayHelper::get( $column, 'header_html_content' ) ) {
					$columnTitle = do_shortcode( $columnContent );
				}
			}

			$formatted_column = array(
				'name'        => $column['key'],
				'title'       => $columnTitle,
				'breakpoints' => $column['breakpoints'],
				'type'        => $columnType,
				'sortable'    => $globalSorting,
				'visible'     => ( $column['breakpoints'] == 'hidden' ) ? false : true,
				'classes'     => $columnClasses,
				'filterable'  => ( isset( $column['unfilterable'] ) && $column['unfilterable'] == 'yes' ) ? false : true
			);

			if ( $columnType == 'date' ) {
				wp_enqueue_script(
					'moment',
					NINJA_TABLES_DIR_URL . "public/libs/moment/moment.min.js",
					[],
					'2.22.0',
					true
				);
				$formatted_column['formatString'] = $column['dateFormat'] ?: 'MM/DD/YYYY';
			}

			if ( $sortingType == 'by_column' && $column['key'] == $settings['sorting_column'] ) {
				$formatted_column['sorted']    = true;
				$formatted_column['direction'] = $settings['sorting_column_by'];
			}
		    
			$formatted_columns[] = apply_filters( 'ninja_table_column_attributes', $formatted_column, $column,
				$table_id, $tableArray );
		}

		if ( $settings['show_all'] ) {
			$pagingSettings = false;
		} else {
			$pagingSettings = ArrayHelper::get( $settings, 'perPage', 20 );
		}

		$enableSearch = ArrayHelper::get( $settings, 'enable_search', false );

		$default_sorting = false;
		if ( $sortingType == 'manual_sort' ) {
			$default_sorting = 'manual_sort';
		} elseif ( isset( $settings['default_sorting'] ) ) {
			$default_sorting = $settings['default_sorting'];
		}

		$configSettings = array(
			'filtering'       => $enableSearch,
			'paging'          => $pagingSettings,
			'sorting'         => true,
			'default_sorting' => $default_sorting,
			'defualt_filter'  => isset( $default_filter ) ? $default_filter : false,
			'expandFirst'     => ( isset( $settings['expand_type'] ) && $settings['expand_type'] == 'expandFirst' )
				? true : false,
			'expandAll'       => ( isset( $settings['expand_type'] ) && $settings['expand_type'] == 'expandAll' ) ? true
				: false,
			'i18n'            => array(
				'search_in'      => ( isset( $settings['search_in_text'] ) )
					? sanitize_text_field( $settings['search_in_text'] ) : __( 'Search in', 'ninja-tables' ),
				'search'         => ( isset( $settings['search_placeholder'] ) )
					? sanitize_text_field( $settings['search_placeholder'] ) : __( 'Search', 'ninja-tables' ),
				'no_result_text' => ( isset( $settings['no_result_text'] ) )
					? sanitize_text_field( $settings['no_result_text'] ) : __( 'No Result Found', 'ninja-tables' ),
			),
			'shouldNotCache'  => isset( $settings['shouldNotCache'] ) ? $settings['shouldNotCache'] : false
		);

		$table_classes = self::getTableCssClass( $settings );

		$tableHasColor = '';
		
		if ( ( ArrayHelper::get( $settings, 'table_color_type' ) == 'pre_defined_color'
               && ArrayHelper::get( $settings, 'table_color' )
		       && ArrayHelper::get( $settings, 'table_color' ) != 'ninja_no_color_table' )
		) {
			$tableHasColor = 'colored_table';
			$table_classes .= ' inverted';
		}
		if ( ArrayHelper::get( $settings, 'table_color_type' ) == 'custom_color' ) {
			$tableHasColor = 'colored_table';
			$table_classes .= ' inverted ninja_custom_color ninja_custom_color';
		}

		if($pagingPosition = ArrayHelper::get($settings, 'pagination_position')) {
			$table_classes .= ' footable-paging-'.$pagingPosition;
		} else {
			$table_classes .= ' footable-paging-right';
		}
		
		if ( isset( $settings['hide_all_borders'] ) && $settings['hide_all_borders'] ) {
			$table_classes .= ' hide_all_borders';
		}

		if ( isset( $settings['hide_header_row'] ) && $settings['hide_header_row'] ) {
			$table_classes .= ' ninjatable_hide_header_row';
		}

		if ( ! $enableSearch ) {
			$table_classes .= ' ninja_table_search_disabled';
		}

		if ( defined( 'NINJATABLESPRO' ) ) {
			$table_classes .= ' ninja_table_pro';
		}

		$table_vars = array(
			'table_id'    => $table_id,
			'columns'     => $formatted_columns,
			'settings'    => $configSettings,
			'render_type' => $renderType,
			'custom_css'  => $customCss
		);
        
		self::addInlineVars( json_encode( $table_vars, true ), $table_id, $table_instance_name );
		$foo_table_attributes = self::getFootableAtrributes( $table_id );

		static::addCustomColorCSS( $tableArray, $columnContentCss );

		include 'views/ninja_foo_table.php';
	}
	
	public static function getTableHTML( $table, $table_vars ) {

		if ( $table_vars['render_type'] == 'ajax_table' ) {
			return;
		}
		if ( $table_vars['render_type'] == 'legacy_table' ) {
			self::generateLegacyTableHTML( $table, $table_vars );

			return;
		}
	}

	private static function generateLegacyTableHTML( $table, $table_vars ) {
		$shouldNotCache = $table_vars['settings']['shouldNotCache'] === 'yes';

		$disableCache = apply_filters( 'ninja_tables_disable_caching', $shouldNotCache, $table->ID );

		$tableHtml = get_post_meta( $table->ID, '_ninja_table_cache_html', true );

		if ( $tableHtml && ! $disableCache ) {
			echo $tableHtml;

			return;
		}
		$tableColumns = $table_vars['columns'];

		$formatted_data = ninjaTablesGetTablesDataByID( $table->ID, $table_vars['settings']['default_sorting'] );
		$tableHtml      = self::loadView( 'public/views/table_inner_html', array(
			'table_columns' => $tableColumns,
			'table_rows'    => $formatted_data
		) );

		if ( ! $disableCache ) {
			update_post_meta( $table->ID, '_ninja_table_cache_html', $tableHtml );
		}
		echo do_shortcode( $tableHtml );

		return;
	}

	private static function loadView( $file, $data ) {
		$file = NINJA_TABLES_DIR_PATH . $file . '.php';
		ob_start();
		extract( $data );
		include $file;

		return ob_get_clean();
	}

	private static function getTableCssClass( $settings ) {
		$tableCassClasses = array(
			self::getTableClassByLib( $settings['css_lib'] ),
			ArrayHelper::get( $settings, 'extra_css_class', '' )
		);

		if (
			ArrayHelper::get( $settings, 'table_color_type' ) == 'pre_defined_color'
			&& ArrayHelper::get( $settings, 'table_color' ) != 'ninja_no_color_table'
		) {
			$tableCassClasses[] = ArrayHelper::get( $settings, 'table_color' );
		}

		$definedClasses = ArrayHelper::get( $settings, 'css_classes', array() );
		$classArray     = array_merge( $tableCassClasses, $definedClasses );
		$uniqueCssArray = array_unique( $classArray );

		return implode( ' ', $uniqueCssArray );
	}

	private static function getTableClassByLib( $lib = 'bootstrap3' ) {
		switch ( $lib ) {
			case 'bootstrap3':
			case 'bootstrap4':
				return 'table';
			case 'semantic_ui':
				return 'ui table';
			default:
				return '';
		}
	}

	private static function addInlineVars( $vars, $table_id, $table_instance_name ) {

		add_action( 'wp_footer', function () use ( $vars, $table_id, $table_instance_name ) {
			?>
            <script type="text/javascript">
                window['<?php echo $table_instance_name;?>'] = <?php echo $vars; ?>
            </script>
			<?php
		} );
	}

	public static function getColumnType( $column ) {
		$type          = ( isset( $column['data_type'] ) ) ? $column['data_type'] : 'text';
		$acceptedTypes = array(
			'text',
			'number',
			'date',
			'html'
		);

		if ( in_array( $type, $acceptedTypes ) ) {
		    if($type == 'number') {
		        return 'numeric';
            }
			return $type;
		}

		return 'text';
	}

	private static function getFootableAtrributes( $tableID ) {
		$atts = array(
			'data-footable_id' => $tableID,
		);

		$atts = apply_filters( 'ninja_table_attributes', $atts, $tableID );

		$atts_string = '';
		foreach ( $atts as $att_name => $att ) {
			$atts_string .= $att_name . '="' . $att . '"';
		}

		return (string) $atts_string;
	}

	public static function getFormattedColumn( $column, $index, $settings, $globalSorting, $sortingType ) {
		$columnType    = self::getColumnType( $column );
		$cssColumnName = 'ninja_column_' . $index;
		$columnClasses = array( $cssColumnName );
		if ( isset( $column['classes'] ) ) {
			$userClasses   = explode( ' ', $column['classes'] );
			$columnClasses = array_unique( array_merge( $columnClasses, $userClasses ) );
		}
		$customCss[ $cssColumnName ] = array();
		if ( $columnWidth = ArrayHelper::get( $column, 'width' ) ) {
			$customCss[ $cssColumnName ]['width'] = $columnWidth . 'px';
		}
		if ( $textAlign = ArrayHelper::get( $column, 'textAlign' ) ) {
			$customCss[ $cssColumnName ]['textAlign'] = $textAlign;
		}
		$columnTitle = $column['name'];
		if ( ArrayHelper::get( $column, 'enable_html_content' ) == 'true' ) {
			if ( $columnContent = ArrayHelper::get( $column, 'header_html_content' ) ) {
				$columnTitle = do_shortcode( $columnContent );
			}
		}
		$formatted_column = array(
			'name'        => $column['key'],
			'title'       => $columnTitle,
			'breakpoints' => $column['breakpoints'],
			'type'        => $columnType,
			'sortable'    => $globalSorting,
			'visible'     => ( $column['breakpoints'] == 'hidden' ) ? false : true,
			'classes'     => $columnClasses,
			'filterable'  => ( isset( $column['unfilterable'] ) && $column['unfilterable'] == 'yes' ) ? false : true
		);
		if ( $columnType == 'date' ) {
			wp_enqueue_script(
				'moment',
				NINJA_TABLES_DIR_URL . "public/libs/moment/moment.min.js",
				[],
				'2.22.0',
				true
			);
			$formatted_column['formatString'] = $column['dateFormat'] ?: 'MM/DD/YYYY';
		}
		if ( $sortingType == 'by_column' && $column['key'] == $settings['sorting_column'] ) {
			$formatted_column['sorted']    = true;
			$formatted_column['direction'] = $settings['sorting_column_by'];
		}
		return $formatted_column;
	}

}
