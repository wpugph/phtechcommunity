<?php
/**
 * Plugin Name: Pantheon WAF Setup
 * Description: Configures Wordfence and Jetpack WAF for Pantheon's read-only filesystem
 * Version: 1.0.0
 * Author: EventsPH
 */

/**
 * On Pantheon, only wp-content/uploads is writable.
 * This plugin ensures WAF logs and configs are written to the correct location.
 *
 * Reference: https://docs.pantheon.io/symlinks-assumed-write-access
 */

// Ensure we're on Pantheon or allow local override
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Set up WAF directories in uploads for Pantheon
 */
function pantheon_setup_waf_directories() {
    // Only run on Pantheon or if explicitly enabled
    $is_pantheon = (isset($_ENV['PANTHEON_ENVIRONMENT']) || getenv('PANTHEON_ENVIRONMENT'));

    if (!$is_pantheon && !defined('PANTHEON_WAF_SETUP_FORCE')) {
        return;
    }

    $upload_dir = wp_upload_dir();
    $uploads_base = $upload_dir['basedir'];

    // Directories that need to be in uploads
    $waf_dirs = [
        'wflogs'      => 'wordfence-waf-logs',  // Wordfence logs
        'jetpack-waf' => 'jetpack-waf',         // Jetpack WAF
    ];

    foreach ($waf_dirs as $source => $target) {
        $source_path = WP_CONTENT_DIR . '/' . $source;
        $target_path = $uploads_base . '/private/' . $target;

        // Create target directory if it doesn't exist
        if (!file_exists($target_path)) {
            wp_mkdir_p($target_path);

            // Note: Pantheon uses nginx (not Apache), so .htaccess won't work.
            // The /private/ directory is automatically protected by Pantheon's nginx config.
        }

        // If source exists and is a real directory (not a symlink), move it
        if (file_exists($source_path) && !is_link($source_path)) {
            // Move existing files to target
            if (is_dir($source_path)) {
                // Copy files
                $files = glob($source_path . '/*');
                if ($files) {
                    foreach ($files as $file) {
                        $filename = basename($file);
                        if (!file_exists($target_path . '/' . $filename)) {
                            @copy($file, $target_path . '/' . $filename);
                        }
                    }
                }
                // Remove old directory if we're on Pantheon
                if ($is_pantheon) {
                    // Can't delete on read-only FS, will be handled by deployment
                }
            }
        }

        // Create symlink if it doesn't exist
        if (!file_exists($source_path)) {
            @symlink($target_path, $source_path);
        }
    }
}

// Run on init
add_action('init', 'pantheon_setup_waf_directories', 1);

/**
 * Configure Wordfence for Pantheon
 */
function pantheon_wordfence_config() {
    if (!class_exists('wordfence')) {
        return;
    }

    // Set Wordfence log location to uploads
    if (!defined('WFWAF_LOG_PATH')) {
        $upload_dir = wp_upload_dir();
        define('WFWAF_LOG_PATH', $upload_dir['basedir'] . '/private/wordfence-waf-logs/');
    }
}
add_action('plugins_loaded', 'pantheon_wordfence_config', 1);

/**
 * Configure Jetpack WAF for Pantheon
 */
function pantheon_jetpack_waf_config() {
    // Jetpack WAF configuration
    // The symlink handles the directory location
}
add_action('plugins_loaded', 'pantheon_jetpack_waf_config', 1);
