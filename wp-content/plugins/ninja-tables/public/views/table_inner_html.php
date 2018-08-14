<?php
    $table_columns = array_reverse($table_columns);
    $header_row = '';
    $counter = 1;
?>
<thead>
<tr>
    <?php foreach ($table_columns as $index => $table_column) : ?>
        <?php
            if (strip_tags($table_column['title']) == '#colspan#') {
	            $header_row = '<td class="ninja_temp_cell"></td>'.$header_row;
	            $counter++;
	            continue;
            }
	    $colspan = '';
	    if ($counter > 1) {
		    $colspan = 'colspan="'.$counter.'"';
	    }
	    $header_row = '<th '. $colspan .' class="'.implode(' ', $table_column['classes']).'">'.do_shortcode($table_column['title']).'</th>'.$header_row;
        ?>
    <?php $counter = 1; endforeach; ?>
    <?php echo $header_row; ?>
</tr>
</thead>
<tbody>
<?php
$columnLength = count($table_columns) - 1;
foreach ($table_rows as $row_index => $table_row) :
    $row = '';
    ?>
    <tr class="ninja_table_row_<?php echo $row_index; ?>">
        <?php
        $colSpanCounter = 1; // Make the colspan counter 1 at first
        foreach ($table_columns as $index => $table_column) {
	        $column_value = @$table_row[$table_column['name']];
	        $colspan = '';
            if($index != $columnLength) {
	            if (strip_tags($column_value) == '#colspan#') {
		            $row = '<td class="ninja_temp_cell"></td>'.$row;
		            $colSpanCounter = $colSpanCounter + 1;
		            // if we get #colspan# value then we are increasing colspan counter by 1 and adding a temp column
		            continue;
	            }
            }
            
	        if ($colSpanCounter > 1) {
		        $colspan = ' colspan="'.$colSpanCounter.'"';
		        // if colspan counter is greater than 1 then we are adding the colspan into the dom
	        }
	        
            $row = '<td'.$colspan.'>'.$column_value.'</td>'.$row;
	        $colSpanCounter = 1;
	        // we are reseting the colspan counter value here because the colspan is done for this iteration
        }
        echo $row;
        ?>
    </tr>
<?php endforeach; ?>
</tbody>