<?php
/**
 * Globally-accessible functions
 *
 * @link           https://authlab.io
 * @since          1.0.0
 *
 * @package        wp_table_data_press
 * @subpackage     wp_table_data_press/includes
 *
 * @param        $tableId
 * @param string $scope
 *
 * @return array
 */
if (!function_exists('ninja_table_get_table_columns')) {
    function ninja_table_get_table_columns($tableId, $scope = 'public')
    {
        $tableColumns = get_post_meta($tableId, '_ninja_table_columns', true);
        if (!$tableColumns || !is_array($tableColumns)) {
            $tableColumns = array();
        }
        return apply_filters('ninja_get_table_columns_'.$scope, $tableColumns,
            $tableId);
    }
}

if (!function_exists('ninja_table_get_table_settings')) {
    function ninja_table_get_table_settings($tableId, $scope = 'public')
    {
        $tableSettings = get_post_meta($tableId, '_ninja_table_settings', true);
	   
        if (!$tableSettings) {
            $tableSettings = getDefaultNinjaTableSettings();
        } else if(empty($tableSettings['css_classes'])) {
	        $tableSettings['css_classes'] = array();
	    }
	    
	    $tableSettings = array_merge(getDefaultNinjaTableSettings(), $tableSettings);
        
        return apply_filters('ninja_get_table_settings_'.$scope, $tableSettings,
            $tableId);
    }
}


if (!function_exists('getDefaultNinjaTableSettings')) {
    function getDefaultNinjaTableSettings()
    {
        $renderType = defined('NINJATABLESPRO') ? 'legacy_table' : 'ajax_table';

        $defaults = array(
            "perPage"         => 20,
            "show_all"        => false,
            "library"         => 'footable',
            "css_lib"         => 'bootstrap3',
            "enable_ajax"     => false,
            "css_classes"     => array(
            	'table-striped',
	            'table-bordered',
	            'table-hover',
	            'vertical_centered'
            ),
            "enable_search"   => true,
            "column_sorting"  => true,
            "default_sorting" => 'new_first',
            "table_color"     => 'ninja_no_color_table',
            "render_type"     => $renderType,
	        "table_color_type" => 'pre_defined_color',
	        "expand_type" => 'default',
        );

        return apply_filters('get_default_ninja_table_settings', $defaults);
    }
}

if (!function_exists('ninja_table_admin_role')) {
    function ninja_table_admin_role()
    {
        if(current_user_can('administrator')) {
            return 'administrator';
        }
        $roles = apply_filters('ninja_table_admin_role', array('administrator'));
        if(is_string($roles)) {
            $roles = array($roles);
        }
        foreach ($roles as $role) {
            if (current_user_can($role)) {
                return $role;
            }
        }
        return false;
    }
}

if (!function_exists('ninja_tables_db_table_name')) {
    function ninja_tables_db_table_name()
    {
        return 'ninja_table_items';
    }
}

if (!function_exists('ninja_tables_DbTable')) {
    function ninja_tables_DbTable()
    {
        return ninjaDB(ninja_tables_db_table_name());
    }
}

if (!function_exists('ninja_table_renameDuplicateValues')) {
    function ninja_table_renameDuplicateValues($values)
    {
        $result = array();

        $scale = array_count_values(array_unique($values));

        foreach ($values as $item) {
            if ($scale[$item] == 1) {
                $result[] = $item;
            } else {
                $result[] = $item.'-'.$scale[$item];
            }

            $scale[$item]++;
        }

        return $result;
    }
}

if (!function_exists('ninja_table_is_in_production_mood')) {
    function ninja_table_is_in_production_mood()
    {
        return apply_filters('ninja_table_is_in_production_mood', false);
    }
}


function ninjaTablesGetTablesDataByID($tableId, $defaultSorting = false, $disableCache = false, $limit = false)
{
    $query = ninja_tables_DbTable()->where('table_id', $tableId);

    if ($defaultSorting == 'new_first') {
        $query->orderBy('id', 'desc');
    } else if ($defaultSorting == 'manual_sort') {
        $query->orderBy('position', 'asc');
    } else {
        $query->orderBy('id', 'asc');
    }

    if($limit) {
	    $query->limit($limit);
    }
    
    $data = $query->get();

    $formatted_data = array();
    foreach ($data as $item) {
        $values = json_decode($item->value, true);
        $values = array_map('do_shortcode', $values);
        $formatted_data[] = $values;
    }

    // Please do not hook this filter unless you don't know what you are doing.
    // Hook ninja_tables_get_public_data instead.
    // You should hook this if you need to cache your filter modifications
    $formatted_data = apply_filters('ninja_tables_get_raw_table_data', $formatted_data, $tableId);

    if (!$disableCache) {
        update_post_meta($tableId, '_ninja_table_cache_object', $formatted_data);
    }

    return $formatted_data;
}

function ninjaTablesClearTableDataCache($tableId)
{
    update_post_meta($tableId, '_ninja_table_cache_object', false);
    update_post_meta($tableId, '_ninja_table_cache_html', false);
}

function ninjaTablesAllowedHtmlTags($tags)
{
    $tags['a']['download'] = true;
    $tags['iframe'] = array(
        'src'             => true,
        'srcdoc'          => true,
        'width'           => true,
        'height'          => true,
        'scrolling'       => true,
        'frameborder'     => true,
        'allow'           => true,
        'style'           => true,
        'allowfullscreen' => true,
        'name'            => true
    );

    return $tags;
}

/**
 * Determine if the table's data has been migrated for manual sorting.
 *
 * @param  int $tableId
 * @return bool
 */
function ninjaTablesDataMigratedForManualSort($tableId)
{
    // The post meta table would have a flag that the data of
    // the table is migrated to use for the manual sorting.
    $postMetaKey = '_ninja_tables_data_migrated_for_manual_sort';

    return !!get_post_meta($tableId, $postMetaKey, true);
}

/**
 * Determine if the user wants to disable the caching for the table.
 *
 * @param  int $tableId
 * @return bool
 */
function shouldNotCache($tableId)
{
    $tableSettings = ninja_table_get_table_settings($tableId, 'public');
    return (isset($tableSettings['shouldNotCache']) && $tableSettings['shouldNotCache'] == 'yes') ? true : false;
}

/**
 * Get the ninja table icon url.
 *
 * @return string
 */
function ninja_table_get_icon_url()
{
    return 'data:image/svg+xml;base64,'
        .base64_encode('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 321.98 249.25"><defs><style>.cls-1{fill:#fff;}.cls-2,.cls-3{fill:none;stroke-miterlimit:10;stroke-width:7px;}.cls-2{stroke:#9fa3a8;}.cls-3{stroke:#38444f;}</style></defs><title>Asset 7</title><g id="Layer_2" data-name="Layer 2"><g id="Layer_1-2" data-name="Layer 1"><path class="cls-1" d="M312.48,249.25H9.5a9.51,9.51,0,0,1-9.5-9.5V9.5A9.51,9.51,0,0,1,9.5,0h303A9.51,9.51,0,0,1,322,9.5V239.75A9.51,9.51,0,0,1,312.48,249.25ZM9.5,7A2.53,2.53,0,0,0,7,9.5V239.75a2.53,2.53,0,0,0,2.5,2.5h303a2.53,2.53,0,0,0,2.5-2.5V9.5a2.53,2.53,0,0,0-2.5-2.5Z"/><rect class="cls-1" x="74.99" y="44.37" width="8.75" height="202.71"/><path class="cls-2" d="M129.37,234.08"/><path class="cls-2" d="M129.37,44.37"/><path class="cls-3" d="M189.37,234.08"/><path class="cls-3" d="M189.37,44.37"/><path class="cls-3" d="M249.37,234.08"/><path class="cls-3" d="M249.37,44.37"/><path class="cls-1" d="M6.16.51H315.82a6,6,0,0,1,6,6V50.32a.63.63,0,0,1-.63.63H.79a.63.63,0,0,1-.63-.63V6.51A6,6,0,0,1,6.16.51Z"/><rect class="cls-1" x="4.88" y="142.84" width="312.61" height="15.1"/><rect class="cls-1" x="22.47" y="89.99" width="28.27" height="16.97"/><rect class="cls-1" x="111.61" y="89.99" width="165.67" height="16.97"/><rect class="cls-1" x="22.47" y="189.99" width="28.27" height="16.97"/><rect class="cls-1" x="111.61" y="189.99" width="165.67" height="16.97"/></g></g></svg>');
}