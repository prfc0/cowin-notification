var filtersConfig = {
  // instruct TableFilter location to import ressources from
  base_path: 'tablefilter/',
  responsive: true,
  col_0: 'select',
  // col_1: 'select',
  col_2: 'select',
  // col_3: 'select',
  // col_4: 'select',
  // col_5: 'select',
  col_6: 'select',
  col_7: 'select',
  // col_8: 'select',
  // col_9: 'select',
  sticky_headers: true,
  alternate_rows: true,
  rows_counter: true,
  btn_reset: true,
  loader: true,
  mark_active_columns: true,
  highlight_keywords: true,
  no_results_message: true,
  col_types: [
    'string', 'string', 'date',
    'string', 'string', 'number',
    'string', 'string', 'number'
  ],

  extensions: [/*{
    name: 'colsVisibility',
    // at_start: [12, 16, 17, 18, 20, 21],
    text: 'Columns: ',
    tickToHide: false,
    toolbar_position: 'left',
    enable_tick_all: false
    },*/ {
    name: 'sort',
    // images_path: 'https://unpkg.com/tablefilter@latest/dist/tablefilter/style/themes/'
    images_path: 'tablefilter/style/themes/'
  }],
  /*
  themes: [{
    name: 'transparent'
  }]
  */
};
var tf = new TableFilter('cowin', filtersConfig);
tf.init();
