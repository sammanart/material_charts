import 'package:flutter/material.dart';
import 'package:material_charts/material_charts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Material Charts Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ChartsDemo(),
    );
  }
}

class ChartsDemo extends StatefulWidget {
  const ChartsDemo({super.key});

  @override
  State<ChartsDemo> createState() => _ChartsDemoState();
}

class _ChartsDemoState extends State<ChartsDemo> {
  int _selectedIndex = 0;

  final List<Widget> _charts = [
    const LineChartExample(),
    const BarChartExample(),
    const PieChartExample(),
    const AreaChartExample(),
    const TreemapChartExample(),
    const MultiLineChartExample(),
    const StackedBarChartExample(),
    const HollowSemiCircleExample(),
    const GanttChartExample(),
    const CandlestickChartExample(),
    const HybridChartExample(),
  ];

  final List<String> _chartNames = [
    'Line Chart',
    'Bar Chart',
    'Pie Chart',
    'Area Chart',
    'Treemap Chart',
    'Multi-Line Chart',
    'Stacked Bar Chart',
    'Hollow Semi-Circle',
    'Gantt Chart',
    'Candlestick Chart',
    'Hybrid Chart (Area/Candlestick)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_chartNames[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _charts[_selectedIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.shifting,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: _chartNames
            .map((name) => BottomNavigationBarItem(
                  icon: const Icon(Icons.bar_chart),
                  label: name,
                  backgroundColor: Colors.blue,
                ))
            .toList(),
      ),
    );
  }
}

// Line Chart Example
class LineChartExample extends StatelessWidget {
  const LineChartExample({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      const ChartData(value: 10, label: 'Jan'),
      const ChartData(value: 25, label: 'Feb'),
      const ChartData(value: 15, label: 'Mar'),
      const ChartData(value: 30, label: 'Apr'),
      const ChartData(value: 45, label: 'May'),
      const ChartData(value: 35, label: 'Jun'),
    ];

    return Column(
      children: [
        const Text(
          'Monthly Sales Data',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        MaterialChartLine(
          data: data,
          width: 350,
          height: 250,
          style: const LineChartStyle(
            lineColor: Colors.blue,
            pointColor: Colors.red,
            useCurvedLines: true,
          ),
        ),
      ],
    );
  }
}

// Bar Chart Example
class BarChartExample extends StatelessWidget {
  const BarChartExample({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      const BarChartData(value: 20, label: 'Product A'),
      const BarChartData(value: 35, label: 'Product B'),
      const BarChartData(value: 25, label: 'Product C'),
      const BarChartData(value: 40, label: 'Product D'),
      const BarChartData(value: 30, label: 'Product E'),
    ];

    return Column(
      children: [
        const Text(
          'Product Sales Comparison',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        MaterialBarChart(
          data: data,
          width: 350,
          height: 300,
          style: const BarChartStyle(
            barColor: Colors.green,
            gradientEffect: true,
            gradientColors: [Colors.green, Colors.lightGreen],
          ),
        ),
      ],
    );
  }
}

// Pie Chart Example
class PieChartExample extends StatelessWidget {
  const PieChartExample({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      const PieChartData(value: 30, label: 'Mobile', color: Colors.blue),
      const PieChartData(value: 25, label: 'Desktop', color: Colors.red),
      const PieChartData(value: 20, label: 'Tablet', color: Colors.green),
      const PieChartData(value: 15, label: 'Watch', color: Colors.orange),
      const PieChartData(value: 10, label: 'Other', color: Colors.purple),
    ];

    return Column(
      children: [
        const Text(
          'Device Usage Distribution',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        MaterialPieChart(
          data: data,
          width: 350,
          height: 300,
          style: const PieChartStyle(
            showLegend: true,
            legendPosition: PieChartLegendPosition.bottom,
          ),
        ),
      ],
    );
  }
}

// Area Chart Example
class AreaChartExample extends StatelessWidget {
  const AreaChartExample({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      const AreaChartData(value: 10, label: 'Q1'),
      AreaChartData(
        value: 20,
        label: "Q2",
        keyEvent: KeyEventData(
          htmlContent: '''
            <div style="font-family: Arial, sans-serif; padding: 4px;">
              <h3 style="margin: 0 0 8px 0; color: #4CAF50; font-size: 14px;">Analyst Rating</h3>
              <div style="font-size: 12px;">
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Date</span>
                  <span style="margin-left: 40px; color: #333;">Oct 28, 2025</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Analyst</span>
                  <span style="margin-left: 40px; color: #333;">UBS</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Rating Action</span>
                  <span style="margin-left: 40px; color: #333;">Maintains</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Rating</span>
                  <span style="margin-left: 40px; color: #333;">Neutral</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Price Action</span>
                  <span style="margin-left: 40px; color: #333;">Raises</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Price Target</span>
                  <span style="margin-left: 40px; color: #333;">87 → 100</span>
                </div>
              </div>
            </div>
          ''',
          markerColor: Colors.green,
          tooltipMaxWidth: 220,
          tooltipOpacity: 1,
        ),
      ),
      const AreaChartData(value: 15, label: 'Q3'),
      AreaChartData(
        value: 35,
        label: 'Q4',
        keyEvent: KeyEventData(
          htmlContent: '''
            <div style="font-family: Arial, sans-serif; padding: 4px;">
              <div style="display: flex; align-items: center; margin-bottom: 8px;">
              <h3 style="margin: 0 0 8px 0; color: #FF6600; font-size: 14px;">Analyst Rating</h3>
              <div style="font-size: 12px;">
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Date</span>
                  <span style="margin-left: 40px; color: #333;">Oct 28, 2025</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Analyst</span>
                  <span style="margin-left: 40px; color: #333;">UBS</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Rating Action</span>
                  <span style="margin-left: 40px; color: #333;">Maintains</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Rating</span>
                  <span style="margin-left: 40px; color: #333;">Neutral</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Price Action</span>
                  <span style="margin-left: 40px; color: #333;">Raises</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Price Target</span>
                  <span style="margin-left: 40px; color: #333;">87 → 100</span>
                </div>
              </div>
            </div>
          ''',
          markerColor: Colors.orange,
          tooltipMaxWidth: 220,
          tooltipOpacity: 1,
        ),
      ),
    ];

    final series = [
      AreaChartSeries(
        name: 'Revenue',
        dataPoints: data,
        color: Colors.blue,
        gradientColor: Colors.blue.withValues(alpha: 0),
      ),
    ];

    return Column(
      children: [
        const Text(
          'Quarterly Revenue Trend with Key Events',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        MaterialAreaChart(
          style: AreaChartStyle(
            forceYAxisFromZero: true,
            keyEventMarkerConfig: KeyEventMarkerConfig(
              verticalOffset: 18,
            ),
            crosshair: AreaCrosshairConfig(
                enabled: true,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.grey,
                  color: Colors.white,
                )),
            showKeyEventMarkers: true,
            tooltipStyle: TooltipStyleConfig(
              backgroundColor: Colors.white,
              backgroundOpacity: 0.95,
              borderRadius: 12.0,
              borderWidth: 0.0,
              defaultMaxWidth: 280.0,
              defaultMaxHeight: 250.0,
            ),
            baseline: BaselineConfig(
              show: true,
              //color: Colors.grey.shade400, // The baseline's default color is the same as the chart's line's color.
              strokeWidth: 2.0,
              dashPattern: [5.0, 3.0],
            ),
            xSpanSlots: 12,
          ),
          series: series,
          width: 350,
          height: 250,
        ),
        const SizedBox(height: 10),
        const Text(
          'Hover over markers to see key events with custom tooltip styling',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

// Treemap chart example

class TreemapChartExample extends StatelessWidget {
  const TreemapChartExample({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Treemap> nodes = [Treemap(value: 50, label: 'Node 1'), Treemap(value: 40, label: 'Node 2'), Treemap(value: 30, label: 'Node 3'), Treemap(value: 20, label: 'Node 4'), Treemap(value: 20, label: 'Node 5'), Treemap(value: 11, label: 'Node 6'), Treemap(value: 10, label: 'Node 7'), Treemap(value: 5, label: 'Node 8'), Treemap(value: 1, label: 'Node 9')];

    return Column(
      children: [
        // ---------------------------------------------------
        // Basic Example: Simple treemap with border
        // ---------------------------------------------------
        SizedBox(
          height: 400, // Fixed height for treemap
          child: FlutterTreemap(
            nodes: nodes, // Pass dataset
            border: Border.all(
              color: Colors.white,
            ), // Optional border around tiles
          ),
        ),

        // Section heading for the second example
        Text("Customized Tiles", style: Theme.of(context).textTheme.headlineSmall),

        // ---------------------------------------------------
        // Advanced Example: Custom tile builder & tooltip
        // ---------------------------------------------------
        SizedBox(
          height: 400,
          child: FlutterTreemap(
            nodes: nodes,
            border: Border.all(color: Colors.white),

            // [tileWrapper] allows wrapping each tile with custom widgets.
            // Here we add a tooltip showing the node label & value.
            tileWrapper: (context, child, node, index, rect) {
              return Tooltip(message: '${node.label}\nValue: ${node.value}', child: child);
            },

            // [tileBuilder] lets you override the default tile content.
            // In this example, only the label is shown with custom text style.
            tileBuilder: (context, node, index, rect) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.label ?? '',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// Multi-Line Chart Example
class MultiLineChartExample extends StatelessWidget {
  const MultiLineChartExample({super.key});

  @override
  Widget build(BuildContext context) {
    final series = [
      ChartSeries(
        name: 'Sales',
        dataPoints: const [
          ChartDataPoint(value: 10, label: 'Jan'),
          ChartDataPoint(value: 25, label: 'Feb'),
          ChartDataPoint(value: 15, label: 'Mar'),
          ChartDataPoint(value: 30, label: 'Apr'),
        ],
        color: Colors.blue,
      ),
      ChartSeries(
        name: 'Profit',
        dataPoints: const [
          ChartDataPoint(value: 5, label: 'Jan'),
          ChartDataPoint(value: 12, label: 'Feb'),
          ChartDataPoint(value: 8, label: 'Mar'),
          ChartDataPoint(value: 18, label: 'Apr'),
        ],
        color: Colors.green,
      ),
    ];

    return Column(
      children: [
        const Text(
          'Sales vs Profit Comparison',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        MultiLineChart(
          series: series,
          style: const MultiLineChartStyle(
            colors: [Colors.blue, Colors.green, Colors.red],
            showLegend: true,
          ),
          height: 300,
          width: 350,
        ),
      ],
    );
  }
}

// Stacked Bar Chart Example
class StackedBarChartExample extends StatelessWidget {
  const StackedBarChartExample({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      StackedBarData(
        label: 'Q1',
        segments: const [
          StackedBarSegment(value: 10, color: Colors.red, label: 'Product A'),
          StackedBarSegment(value: 15, color: Colors.blue, label: 'Product B'),
          StackedBarSegment(value: 12, color: Colors.green, label: 'Product C'),
        ],
      ),
      StackedBarData(
        label: 'Q2',
        segments: const [
          StackedBarSegment(value: 15, color: Colors.red, label: 'Product A'),
          StackedBarSegment(value: 20, color: Colors.blue, label: 'Product B'),
          StackedBarSegment(value: 10, color: Colors.green, label: 'Product C'),
        ],
      ),
      StackedBarData(
        label: 'Q3',
        segments: const [
          StackedBarSegment(value: 12, color: Colors.red, label: 'Product A'),
          StackedBarSegment(value: 18, color: Colors.blue, label: 'Product B'),
          StackedBarSegment(value: 15, color: Colors.green, label: 'Product C'),
        ],
      ),
    ];

    return Column(
      children: [
        const Text(
          'Quarterly Product Sales',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        MaterialStackedBarChart(
          data: data,
          width: 350,
          height: 300,
        ),
      ],
    );
  }
}

// Hollow Semi-Circle Chart Example
class HollowSemiCircleExample extends StatelessWidget {
  const HollowSemiCircleExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Goal Achievement',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        MaterialChartHollowSemiCircle(
          percentage: 75,
          size: 200,
          hollowRadius: 0.6,
          style: const ChartStyle(
            activeColor: Colors.green,
            inactiveColor: Colors.grey,
            showPercentageText: true,
          ),
        ),
        const SizedBox(height: 20),
        const Text('75% Complete'),
      ],
    );
  }
}

// Gantt Chart Example
class GanttChartExample extends StatelessWidget {
  const GanttChartExample({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      GanttData(
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 2, 15),
        label: 'Planning Phase',
        color: Colors.blue,
        description: 'Initial project planning and requirements gathering',
      ),
      GanttData(
        startDate: DateTime(2024, 2, 1),
        endDate: DateTime(2024, 4, 30),
        label: 'Development Phase',
        color: Colors.green,
        description: 'Core development and implementation',
      ),
      GanttData(
        startDate: DateTime(2024, 4, 15),
        endDate: DateTime(2024, 5, 30),
        label: 'Testing Phase',
        color: Colors.orange,
        description: 'Quality assurance and testing',
      ),
      GanttData(
        startDate: DateTime(2024, 5, 20),
        endDate: DateTime(2024, 6, 15),
        label: 'Deployment',
        color: Colors.red,
        description: 'Production deployment and monitoring',
      ),
    ];

    return Column(
      children: [
        const Text(
          'Project Timeline',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        MaterialGanttChart(
          data: data,
          width: 350,
          height: 300,
        ),
      ],
    );
  }
}

// Candlestick Chart Example
class CandlestickChartExample extends StatelessWidget {
  const CandlestickChartExample({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      CandlestickData(
        date: DateTime(2024, 1, 1),
        open: 100,
        high: 110,
        low: 95,
        close: 105,
      ),
      CandlestickData(
        date: DateTime(2024, 1, 2),
        open: 105,
        high: 115,
        low: 100,
        close: 108,
        keyEvent: const KeyEventData(
          htmlContent: '''
            <div style="font-family: Arial, sans-serif; padding: 4px;">
              <h3 style="margin: 0 0 8px 0; color: #4CAF50; font-size: 14px;">Analyst Rating</h3>
              <div style="font-size: 12px;">
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Date</span>
                  <span style="margin-left: 40px; color: #333;">Oct 28, 2025</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Analyst</span>
                  <span style="margin-left: 40px; color: #333;">UBS</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Rating Action</span>
                  <span style="margin-left: 40px; color: #333;">Maintains</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Rating</span>
                  <span style="margin-left: 40px; color: #333;">Neutral</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Price Action</span>
                  <span style="margin-left: 40px; color: #333;">Raises</span>
                </div>
                <div style="margin-bottom: 4px;">
                  <span style="color: #666;">Price Target</span>
                  <span style="margin-left: 40px; color: #333;">87 → 100</span>
                </div>
              </div>
            </div>
          ''',
          markerColor: Colors.green,
          tooltipMaxWidth: 220,
          tooltipOpacity: 1,
        ),
      ),
      CandlestickData(
        date: DateTime(2024, 1, 3),
        open: 108,
        high: 120,
        low: 102,
        close: 112,
      ),
      CandlestickData(
        date: DateTime(2024, 1, 4),
        open: 112,
        high: 118,
        low: 108,
        close: 115,
        keyEvent: const KeyEventData(
          htmlContent: '<b>Dividend Announced</b><br/>\$0.50 per share<br/>Ex-date: Jan 15',
          markerColor: Colors.green,
        ),
      ),
      CandlestickData(
        date: DateTime(2024, 1, 5),
        open: 115,
        high: 125,
        low: 110,
        close: 120,
      ),
    ];

    return Column(
      children: [
        const Text(
          'Stock Price Movement',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        MaterialCandlestickChart(
          data: data,
          width: 350,
          height: 300,
        ),
      ],
    );
  }
}

// Hybrid Chart Example 
class HybridChartExample extends StatelessWidget {
  const HybridChartExample({super.key});

  @override
  Widget build(BuildContext context) {
    final hybridData = [
      HybridChartData(label: 'Jan 1', open: 100, high: 113, low: 85, close: 105, volume: 10500),
      HybridChartData(label: 'Jan 2', open: 105, high: 112, low: 89, close: 99, volume: 9900),
      HybridChartData(label: 'Jan 3', open: 99, high: 114, low: 83, close: 100, volume: 10000),
      HybridChartData(label: 'Jan 4', open: 100, high: 118, low: 99, close: 109, volume: 10900),
      HybridChartData(label: 'Jan 5', open: 109, high: 120, low: 88, close: 99, volume: 9900, keyEvent: const KeyEventData(htmlContent: '<b>Weekly High</b><br/>Reached 120', markerColor: Colors.green)),
      HybridChartData(label: 'Jan 6', open: 99, high: 119, low: 99, close: 114, volume: 11400),
      HybridChartData(label: 'Jan 7', open: 114, high: 119, low: 84, close: 110, volume: 11000),
      HybridChartData(label: 'Jan 8', open: 110, high: 110, low: 89, close: 91, volume: 9100),
      HybridChartData(label: 'Jan 9', open: 91, high: 115, low: 91, close: 111, volume: 11100),
      HybridChartData(label: 'Jan 10', open: 111, high: 116, low: 96, close: 110, volume: 11100),
      HybridChartData(label: 'Jan 11', open: 110, high: 115, low: 83, close: 101, volume: 10100),
      HybridChartData(label: 'Jan 12', open: 101, high: 117, low: 86, close: 92, volume: 9200),
      HybridChartData(label: 'Jan 13', open: 92, high: 117, low: 92, close: 112, volume: 11200),
      HybridChartData(label: 'Jan 14', open: 112, high: 113, low: 101, close: 104, volume: 10400),
      HybridChartData(label: 'Jan 15', open: 104, high: 114, low: 94, close: 107, volume: 10700),
      HybridChartData(label: 'Jan 16', open: 107, high: 117, low: 92, close: 109, volume: 10900),
      HybridChartData(label: 'Jan 17', open: 109, high: 110, low: 81, close: 90, volume: 9000),
      HybridChartData(label: 'Jan 18', open: 90, high: 102, low: 86, close: 99, volume: 9900),
      HybridChartData(label: 'Jan 19', open: 99, high: 117, low: 99, close: 114, volume: 11400),
      HybridChartData(label: 'Jan 20', open: 114, high: 120, low: 90, close: 93, volume: 9300, keyEvent: const KeyEventData(htmlContent: '<b>High Volatility</b><br/>Range: 90-120', markerColor: Colors.orange)),
      HybridChartData(label: 'Jan 21', open: 93, high: 106, low: 91, close: 103, volume: 10300),
      HybridChartData(label: 'Jan 22', open: 103, high: 104, low: 81, close: 103, volume: 10300),
      HybridChartData(label: 'Jan 23', open: 103, high: 112, low: 83, close: 100, volume: 10000),
      HybridChartData(label: 'Jan 24', open: 100, high: 115, low: 84, close: 90, volume: 9000),
      HybridChartData(label: 'Jan 25', open: 90, high: 112, low: 90, close: 96, volume: 9600),
      HybridChartData(label: 'Jan 26', open: 96, high: 104, low: 82, close: 93, volume: 9300),
      HybridChartData(label: 'Jan 27', open: 93, high: 114, low: 86, close: 89, volume: 8900),
      HybridChartData(label: 'Jan 28', open: 89, high: 109, low: 86, close: 95, volume: 9500),
      HybridChartData(label: 'Jan 29', open: 95, high: 117, low: 84, close: 111, volume: 11100),
      HybridChartData(label: 'Jan 30', open: 111, high: 112, low: 81, close: 88, volume: 8800),
      HybridChartData(label: 'Jan 31', open: 88, high: 102, low: 80, close: 91, volume: 9100),
    ];

    final hybridData2 = [
      HybridChartData(label: 'Jan 1', open: 145, high: 158, low: 130, close: 150, volume: 15000),
      HybridChartData(label: 'Jan 2', open: 150, high: 157, low: 134, close: 144, volume: 14400),
      HybridChartData(label: 'Jan 3', open: 144, high: 159, low: 128, close: 145, volume: 14500),
      HybridChartData(label: 'Jan 4', open: 145, high: 163, low: 144, close: 154, volume: 15400),
      HybridChartData(label: 'Jan 5', open: 154, high: 165, low: 133, close: 144, volume: 14400),
      HybridChartData(label: 'Jan 6', open: 144, high: 164, low: 144, close: 159, volume: 15900),
      HybridChartData(label: 'Jan 7', open: 159, high: 164, low: 129, close: 155, volume: 15500),
      HybridChartData(label: 'Jan 8', open: 155, high: 155, low: 134, close: 136, volume: 13600),
      HybridChartData(label: 'Jan 9', open: 136, high: 160, low: 136, close: 156, volume: 15600),
      HybridChartData(label: 'Jan 10', open: 156, high: 161, low: 141, close: 156, volume: 15600),
      HybridChartData(label: 'Jan 11', open: 156, high: 160, low: 128, close: 146, volume: 14600),
      HybridChartData(label: 'Jan 12', open: 146, high: 162, low: 131, close: 137, volume: 13700),
      HybridChartData(label: 'Jan 13', open: 137, high: 162, low: 137, close: 157, volume: 15700),
      HybridChartData(label: 'Jan 14', open: 157, high: 158, low: 146, close: 149, volume: 14900),
      HybridChartData(label: 'Jan 15', open: 149, high: 159, low: 139, close: 152, volume: 15200),
      HybridChartData(label: 'Jan 16', open: 152, high: 162, low: 137, close: 154, volume: 15400),
      HybridChartData(label: 'Jan 17', open: 154, high: 155, low: 126, close: 135, volume: 13500),
      HybridChartData(label: 'Jan 18', open: 135, high: 147, low: 131, close: 144, volume: 14400),
      HybridChartData(label: 'Jan 19', open: 144, high: 162, low: 144, close: 159, volume: 15900),
      HybridChartData(label: 'Jan 20', open: 159, high: 165, low: 135, close: 138, volume: 13800),
      HybridChartData(label: 'Jan 21', open: 138, high: 151, low: 136, close: 148, volume: 14800),
      HybridChartData(label: 'Jan 22', open: 148, high: 149, low: 126, close: 148, volume: 14800),
      HybridChartData(label: 'Jan 23', open: 148, high: 157, low: 128, close: 145, volume: 14500),
      HybridChartData(label: 'Jan 24', open: 145, high: 160, low: 129, close: 135, volume: 13500),
      HybridChartData(label: 'Jan 25', open: 135, high: 157, low: 135, close: 141, volume: 14100),
      HybridChartData(label: 'Jan 26', open: 141, high: 149, low: 127, close: 138, volume: 13800),
      HybridChartData(label: 'Jan 27', open: 138, high: 159, low: 131, close: 134, volume: 13400),
      HybridChartData(label: 'Jan 28', open: 134, high: 154, low: 131, close: 140, volume: 14000),
      HybridChartData(label: 'Jan 29', open: 140, high: 162, low: 129, close: 156, volume: 15600),
      HybridChartData(label: 'Jan 30', open: 156, high: 157, low: 126, close: 133, volume: 13300),
      HybridChartData(label: 'Jan 31', open: 133, high: 147, low: 125, close: 136, volume: 13600),
    ];

    final hybridSeries = [
      HybridChartSeries(
        name: 'AAPL',
        dataPoints: hybridData,
        color: Colors.green,
      ),
      // HybridChartSeries(
      //   name: 'MSFT',
      //   dataPoints: hybridData2,
      //   color: Colors.blue,
      // ),
    ];

    return Column(
      children: [
        const Text(
          'Hybrid Chart (Area + Candlestick + MultiLine)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 800,
          height: 400,
          child: MaterialHybridChart(
            showChartTypeToggle: false,
            series: hybridSeries,
            width: 800,
            height: 400,
            initialChartType: HybridChartType.area,
            axisConfig: HybridChartAxisConfig(
              yAxisWidth: 10.0,
              xAxisHeight: 25.0,
              yAxisPosition: YAxisPosition.right,
              xAxisPosition: XAxisPosition.bottom,
            ),
            style: HybridChartStyle.unified(
              xAxisTitle: 'Date',
              yAxisTitle: 'Price (USD)',
              xAxisTitleStyle: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
              yAxisTitleStyle: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w600),
              tooltipStyle: TooltipStyleConfig(borderWidth: 10),
              padding: EdgeInsets.fromLTRB(10, 10, 60, 10),
              chartAreaBackgroundColor: Colors.white,
              keyEventMarkerConfig: KeyEventMarkerConfig(
                verticalOffset: 18,
                defaultColor: Colors.red,
                minHoverRadius: 15,
                size: 10,
              ),
              showVolumeTooltip: true,
              showVolume: true,
              volumeTooltipBackgroundColor: Colors.black,
              volumeTooltipTextColor: Colors.white,
              volumeTooltipOpacity: 0.6,
              volumeTooltipBorderRadius: 6.0,
              volumeBarColor: Colors.grey,
              volumeBarOpacity: 0.6,
              volumeBarWidth: 10.0,
              volumeBarHeightRatio: 0.2,
              showGrid: false,
              showPoints: false,
              candleWidth: 10.0,
              wickWidth: 2.0,
              defaultPointSize: 4.0,
              forceYAxisFromZero: true,
              colors: [Colors.blue, Colors.green, Colors.red],
              showKeyEventMarkers: true,
              bullishColor: Colors.green,
              bearishColor: Colors.red,
              areaFillOpacityTop: 0.5,
              areaFillOpacityBottom: 0.0,
              yAxisMaxOffset: 50,
              xSpanSlots: 35,
              gridColor: Colors.grey,
              gridStrokeWidth: 0.5,
              gridOpacity: 1.00,
              showVerticalLinesAtEveryLabels: false,
              yAxisColor: Colors.black,
              xAxisColor: Colors.black,
              yAxisOpacity: 0.50,
              xAxisOpacity: 0.50,
              xAxisStrokeWidth: 3.00,
              yAxisStrokeWidth: 3.00,
              autoHorizontalGridLines: 3,
              autoVerticalGridLines: 3,
              animationDuration: Duration(seconds: 2),
              singleCrosshair: false,
              singleCrosshairOrientation: SingleCrosshairOrientation.horizontal,
              crosshair: AreaCrosshairConfig(
                lineColor: Colors.grey,
                lineWidth: 1,
                showLabel: true,
                enabled: true,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.grey,
                  color: Colors.white,
                ),
              ),
              baseline: BaselineConfig(
                //color: Colors.black, //falls back to the color of the line if no color is given here
                show: true,
                strokeWidth: 1.5,
                dashPattern: [5.0, 3.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
