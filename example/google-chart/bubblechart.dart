// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// A JS Interop sample accessing the Google Charts API.  The sample is based on
// the Bubble Chart example here:
// https://developers.google.com/chart/interactive/docs/gallery/bubblechart

#import('dart:html');
// TODO(vsm): Make this a package path.
#import('../../lib/js.dart', prefix: 'js');

main() {
  drawVisualization(_) {
    var google = js.context.google;

    // Create and populate the data table.
    var data = google.visualization.arrayToDataTable(js.array(
      [
        ['ID', 'Life Expectancy', 'Fertility Rate', 'Region',     'Population'],
        ['CAN',    80.66,              1.67,      'North America',  33739900],
        ['DEU',    79.84,              1.36,      'Europe',         81902307],
        ['DNK',    78.6,               1.84,      'Europe',         5523095],
        ['EGY',    72.73,              2.78,      'Middle East',    79716203],
        ['GBR',    80.05,              2,         'Europe',         61801570],
        ['IRN',    72.49,              1.7,       'Middle East',    73137148],
        ['IRQ',    68.09,              4.77,      'Middle East',    31090763],
        ['ISR',    81.55,              2.96,      'Middle East',    7485600],
        ['RUS',    68.6,               1.54,      'Europe',         141850000],
        ['USA',    78.09,              2.05,      'North America',  307007000]
      ]));

    var options = js.map({
      'title': 'Correlation between life expectancy, fertility rate and population of some world countries (2010)',
      'hAxis': {'title': 'Life Expectancy'},
      'vAxis': {'title': 'Fertility Rate'},
      'bubble': {'textStyle': {'fontSize': 11}}
    });

    // Create and draw the visualization.
    var chart = new js.Proxy(google.visualization.BubbleChart,
                             query('#visualization'));
    chart.draw(data, options);
  }

  js.scoped(() {
    js.context.google.setOnLoadCallback(
        new js.Callback.once(drawVisualization));
  });
}