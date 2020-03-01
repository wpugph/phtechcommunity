<?php namespace NinjaTables\Classes;

class ProcessDemoPage {
	public function handleExteriorPages() {
		if ( isset( $_GET['ninjatable_preview'] ) && $_GET['ninjatable_preview'] ) {
			if(ninja_table_admin_role()) {
				$tableId = intval( $_GET['ninjatable_preview'] );
				$this->loadDefaultPageTemplate();
				$this->renderPreview( $tableId );
			}
		}
	}

	public function renderPreview( $table_id ) {
		$table = get_post( $table_id );
		if ( $table ) {
			add_action( 'pre_get_posts', array( $this, 'pre_get_posts' ), 100, 1 );
			add_filter( 'post_thumbnail_html', '__return_empty_string' );
			add_filter( 'get_the_excerpt', function ( $content ) {
				return '';
			} );
			add_filter( 'the_title', function ( $title ) use ( $table ) {
				if ( in_the_loop() ) {
					return $table->post_title;
				}

				return $title;
			}, 100, 1 );
			add_filter( 'the_content', function ( $content ) use ( $table ) {
				if ( in_the_loop() ) {
					$content = '<div style="text-align: center" class="demo"><h3>Ninja Table Demo Preview ( Table ID: '.$table->ID.' )</h3></div><hr />';
					$content .= '[ninja_tables id=' . $table->ID . ']';
				}
				return $content;
			} );
		}
	}

	private function loadDefaultPageTemplate() {
		add_filter( 'template_include', function ( $original ) {
			return locate_template( array( 'page.php', 'single.php', 'index.php' ) );
		} );
	}

	/**
	 * Set the posts to one
	 *
	 * @param  WP_Query $query
	 *
	 * @return void
	 */
	public function pre_get_posts( $query ) {
		if ( $query->is_main_query() ) {
			$query->set( 'posts_per_page', 1 );
		}
	}

}