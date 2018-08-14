<style type="text/css">
<?php if($colors): ?>
<?php echo $css_prefix; ?> {
    background-color: <?php echo $colors['table_color_primary']; ?> !important;
    color: <?php echo $colors['table_color_secondary']; ?> !important;
}
<?php echo $css_prefix; ?> thead tr.footable-filtering th {
    background-color: <?php echo $colors['table_search_color_primary']; ?> !important;
    color: <?php echo $colors['table_search_color_secondary']; ?> !important;
}
<?php echo $css_prefix; ?>:not(.hide_all_borders) thead tr.footable-filtering th {
    <?php if($colors['table_search_color_border']): ?>
	 border : 1px solid <?php echo $colors['table_search_color_border']; ?> !important;
    <?php else: ?>
    border : 1px solid transparent !important;
    <?php endif; ?>
}
<?php echo $css_prefix; ?> .input-group-btn:last-child > .btn:not(:last-child):not(.dropdown-toggle) {
    background-color: <?php echo $colors['table_search_color_secondary']; ?> !important;
    color: <?php echo $colors['table_search_color_primary']; ?> !important;
}
<?php echo $css_prefix; ?> tr.footable-header, <?php echo $css_prefix; ?> tr.footable-header th {
    background-color: <?php echo $colors['table_header_color_primary']; ?> !important;
    color: <?php echo $colors['table_color_header_secondary']; ?> !important;
}
<?php echo $css_prefix; ?>:not(.hide_all_borders) tr.footable-header th {
    border-color: <?php echo $colors['table_color_header_border']; ?> !important;
}
<?php echo $css_prefix; ?>:not(.hide_all_borders) tbody tr td {
    border-color: <?php echo $colors['table_color_border']; ?> !important;
}

<?php if($colors['alternate_color_status']): ?>
<?php echo $css_prefix; ?> tbody tr:nth-child(even) {
    background-color: <?php echo $colors['table_alt_color_primary']; ?>;
    color: <?php echo $colors['table_alt_color_secondary']; ?>;
}
<?php echo $css_prefix; ?> tbody tr:nth-child(odd) {
    background-color: <?php echo $colors['table_alt_2_color_primary']; ?>;
    color: <?php echo $colors['table_alt_2_color_secondary']; ?>;
}
<?php echo $css_prefix; ?> tbody tr:nth-child(even):hover {
    background-color: <?php echo $colors['table_alt_color_hover']; ?>;
}
<?php echo $css_prefix; ?> tbody tr:nth-child(odd):hover {
    background-color: <?php echo $colors['table_alt_2_color_hover']; ?>;
}
<?php endif; ?>

<?php echo $css_prefix; ?> tfoot .footable-paging {
    background-color: <?php echo $colors['table_footer_bg']; ?> !important;
}
<?php echo $css_prefix; ?> tfoot .footable-paging .footable-page.active a {
    background-color: <?php echo $colors['table_footer_active']; ?> !important;
}
<?php echo $css_prefix; ?>:not(.hide_all_borders) tfoot tr.footable-paging td {
    border-color: <?php echo $colors['table_footer_border']; ?> !important;
}
<?php endif; ?>
<?php echo $custom_css; ?>
</style> 