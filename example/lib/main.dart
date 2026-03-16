import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_charts/material_charts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

Future<Uint8List> _capturePng(GlobalKey repaintKey, {double pixelRatio = 3.0}) async {
  final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw StateError('RepaintBoundary not found');
  }
  final image = await boundary.toImage(pixelRatio: 100);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('Failed to encode PNG');
  }
  return bytes.buffer.asUint8List();
}

Future<void> _exportChartToPdf(BuildContext context, GlobalKey repaintKey, String title) async {
  try {
    final pngBytes = await _capturePng(repaintKey);
    final doc = pw.Document();
    final image = pw.MemoryImage(pngBytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                //pw.Text(title, style: pw.TextStyle(fontSize: 18)),
                pw.SizedBox(height: 12),
                pw.Image(image, fit: pw.BoxFit.contain),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }
}

Widget _buildExportHeader(BuildContext context, String title, GlobalKey repaintKey, {VoidCallback? onExportSvg, VoidCallback? onExportPdf}) {
  return Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      if (onExportSvg != null)
        IconButton(
          tooltip: 'Export SVG',
          icon: const Icon(Icons.image),
          onPressed: onExportSvg,
        ),
      IconButton(
        tooltip: 'Export PDF',
        icon: const Icon(Icons.picture_as_pdf),
        onPressed: onExportPdf ?? () => _exportChartToPdf(context, repaintKey, title),
      ),
    ],
  );
}

Future<File> _saveSvgToDocuments(String svg, {String? fileName}) async {
  final dir = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final safeName = fileName ?? 'chart_$timestamp.svg';
  final file = File('${dir.path}/$safeName');
  await file.writeAsString(svg);
  return file;
}

// Generic export functions for different chart types

Future<void> _exportBarChartSvg(
  BuildContext context,
  List<BarChartData> data,
  BarChartStyle style,
  String title,
) async {
  try {
    final svg = BarChartSvgExporter.exportSvg(
      data: data,
      style: style,
      width: 350,
      height: 300,
      padding: const EdgeInsets.all(24),
      options: BarChartSvgOptions(
        includeGrid: true,
        includeValues: true,
        includeLabels: true,
        title: title,
      ),
    );

    final file = await _saveSvgToDocuments(svg, fileName: 'bar_chart_${DateTime.now().millisecondsSinceEpoch}.svg');
    if (!context.mounted) return;

    await _showSvgPreviewDialog(context, svg, file);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG export failed: $e')),
    );
  }
}

Future<void> _exportPieChartSvg(
  BuildContext context,
  List<PieChartData> data,
  PieChartStyle style,
  String title,
) async {
  try {
    final svg = PieChartSvgExporter.exportSvg(
      data: data,
      style: style,
      width: 500,
      height: 450,
      padding: const EdgeInsets.all(40),
      chartRadius: 120,
      options: PieChartSvgOptions(
        showLabels: true,
        showValues: true,
        showLegend: true,
        showConnectorLines: true,
        title: title,
      ),
    );

    final file = await _saveSvgToDocuments(svg, fileName: 'pie_chart_${DateTime.now().millisecondsSinceEpoch}.svg');
    if (!context.mounted) return;

    await _showSvgPreviewDialog(context, svg, file);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG export failed: $e')),
    );
  }
}

Future<void> _exportPopulationPyramidSvg(
  BuildContext context,
  List<PopulationPyramidData> data,
  PopulationPyramidStyle style,
  String title,
) async {
  try {
    final svg = PopulationPyramidSvgExporter.exportSvg(
      data: data,
      style: style,
      width: 600,
      height: 500,
      padding: const EdgeInsets.all(40),
      options: PopulationPyramidSvgOptions(
        title: title,
      ),
    );

    final file = await _saveSvgToDocuments(svg, fileName: 'population_pyramid_${DateTime.now().millisecondsSinceEpoch}.svg');
    if (!context.mounted) return;

    await _showSvgPreviewDialog(context, svg, file);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG export failed: $e')),
    );
  }
}

Future<void> _exportPopulationPyramidPdf(
  BuildContext context,
  List<PopulationPyramidData> data,
  PopulationPyramidStyle style,
  String title,
) async {
  try {
    final svg = PopulationPyramidSvgExporter.exportSvg(
      data: data,
      style: style,
      width: 600,
      height: 500,
      padding: const EdgeInsets.all(40),
      options: PopulationPyramidSvgOptions(
        title: title,
      ),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.SizedBox(height: 12),
                pw.SvgImage(svg: svg, fit: pw.BoxFit.contain),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF export failed: $e')),
    );
  }
}

Future<void> _exportLineChartSvg(
  BuildContext context,
  List<ChartData> data,
  LineChartStyle style,
  String title,
) async {
  try {
    final svg = LineChartSvgExporter.exportSvg(
      data: data,
      style: style,
      width: 350,
      height: 250,
      padding: const EdgeInsets.all(24),
      options: LineChartSvgOptions(
        includeGrid: true,
        showPoints: true,
        includeLabels: true,
        title: title,
      ),
    );

    final file = await _saveSvgToDocuments(svg, fileName: 'line_chart_${DateTime.now().millisecondsSinceEpoch}.svg');
    if (!context.mounted) return;

    await _showSvgPreviewDialog(context, svg, file);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG export failed: $e')),
    );
  }
}

Future<void> _exportAreaChartSvg(
  BuildContext context,
  List<AreaChartSeries> series,
  AreaChartStyle style,
  String title,
) async {
  try {
    final svg = AreaChartSvgExporter.exportSvg(
      series: series,
      style: style,
      width: 350,
      height: 250,
      padding: const EdgeInsets.all(24),
      options: AreaChartSvgOptions(
        includeGrid: true,
        showPoints: true,
        showKeyEventMarkers: true,
        title: title,
      ),
    );

    final file = await _saveSvgToDocuments(svg, fileName: 'area_chart_${DateTime.now().millisecondsSinceEpoch}.svg');
    if (!context.mounted) return;

    await _showSvgPreviewDialog(context, svg, file);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG export failed: $e')),
    );
  }
}

Future<void> _exportMultiLineChartSvg(
  BuildContext context,
  List<ChartSeries> series,
  MultiLineChartStyle style,
  String title,
) async {
  try {
    final svg = MultiLineChartSvgExporter.exportSvg(
      series: series,
      style: style,
      width: 800,
      height: 400,
      padding: const EdgeInsets.all(48),
      options: MultiLineChartSvgOptions(
        includeGrid: true,
        showPoints: true,
        showLegend: true,
        title: title,
      ),
    );

    final file = await _saveSvgToDocuments(svg, fileName: 'multi_line_chart_${DateTime.now().millisecondsSinceEpoch}.svg');
    if (!context.mounted) return;

    await _showSvgPreviewDialog(context, svg, file);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG export failed: $e')),
    );
  }
}

Future<void> _exportStackedBarChartSvg(
  BuildContext context,
  List<StackedBarData> data,
  StackedBarChartStyle style,
  String title,
) async {
  try {
    final svg = StackedBarChartSvgExporter.exportSvg(
      data: data,
      style: style,
      width: 800,
      height: 400,
      padding: const EdgeInsets.all(48),
      options: StackedBarChartSvgOptions(
        includeGrid: true,
        showValues: true,
        includeLabels: true,
        includeYAxis: true,
        title: title,
      ),
    );

    final file = await _saveSvgToDocuments(svg, fileName: 'stacked_bar_chart_${DateTime.now().millisecondsSinceEpoch}.svg');
    if (!context.mounted) return;

    await _showSvgPreviewDialog(context, svg, file);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG export failed: $e')),
    );
  }
}

Future<void> _showSvgPreviewDialog(BuildContext context, String svg, File file) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('SVG Preview'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _TransparencyCheckerboard()),
                      Positioned.fill(child: SvgPicture.string(svg, fit: BoxFit.contain)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    file.path,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: svg));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SVG copied to clipboard.')),
                );
              }
            },
            child: const Text('Copy SVG'),
          ),
          TextButton(
            onPressed: () async {
              await Share.shareXFiles([XFile(file.path)], text: 'Hybrid chart SVG');
            },
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
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
    BarChartExample(),
    AnimatedBarChartExample(),
    NegativeBarChartExample(),
    GroupedBarChartExample(),
    const ManuallyTriggeredBarChartExample(),
    PieChartExample(),
    PieChartAnimationExample(),
    PopulationChartExample(),
    AreaChartExample(),
    AnimatedAreaChartExample(),
    AnimatedAreaSegmentChartExample(),
    AnimatedAreaManualTriggerExample(),
    AnimatedAreaSegmentTriggersExample(),
    const TreemapChartExample(),
    const MultiLineChartExample(),
    AnimatedMultiLineChartExample(),
    AnimatedSegmentMultiLineChartExample(),
    AnimatedSegmentWithManualTriggerExample(),
    MultiSegmentWithManualTriggersExample(),
    const StackedBarChartExample(),
    const HollowSemiCircleExample(),
    const GanttChartExample(),
    const CandlestickChartExample(),
    const HybridChartAnimationExample(),
    const HybridChartMixedAnimationsExample(),
    const HybridChartExample(),
  ];

  final List<String> _chartNames = [
    'Line Chart',
    'Bar Chart',
    'Animated Bar Chart',
    'Bar Chart (Negatives)',
    'Grouped Bar Chart',
    'Bar Chart: Manual Triggers',
    'Pie Chart',
    'Pie Chart Animated',
    'Population Chart',
    'Area Chart',
    'Animated Area Chart',
    'Animated Area (Segments)',
    'Area Chart: Manual Triggers',
    'Area Chart: Segments Triggers',
    'Treemap Chart',
    'Multi-Line Chart',
    'Animated Multi-Line Chart',
    'Multi-Line with Segment Animations',
    'Multi-Line with Manual Triggers',
    'Multi-Line: Line + Segments + Line',
    'Stacked Bar Chart',
    'Hollow Semi-Circle',
    'Gantt Chart',
    'Candlestick Chart',
    'Hybrid Chart: Animation Examples',
    'Hybrid Chart: Mixed Manual Animations',
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

    const style = LineChartStyle(
      lineColor: Colors.blue,
      pointColor: Colors.red,
      useCurvedLines: true,
    );

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Monthly Sales Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Export SVG',
              icon: const Icon(Icons.image),
              onPressed: () => _exportLineChartSvg(context, data, style, 'Monthly Sales Data'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        MaterialChartLine(
          data: data,
          width: 350,
          height: 250,
          style: style,
        ),
      ],
    );
  }
}

// Bar Chart Example with Negative Values
class NegativeBarChartExample extends StatelessWidget {
  NegativeBarChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final data = [
      const BarChartData(value: -12, label: 'Q1', color: Colors.red),
      const BarChartData(value: 18, label: 'Q2', color: Colors.green),
      const BarChartData(value: -6, label: 'Q3', color: Colors.orange),
      const BarChartData(value: 24, label: 'Q4', color: Colors.blue),
      const BarChartData(value: 1, label: 'Q5', color: Colors.grey),
    ];

    const style = BarChartStyle(
      barSpacing: 0.2,
      gradientEffect: false,
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'Quarterly Performance (+/-)',
          _chartKey,
          onExportSvg: () => _exportBarChartSvg(context, data, style, 'Quarterly Performance (+/-)'),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: _chartKey,
          child: MaterialBarChart(
            data: data,
            width: 380,
            height: 300,
            style: style,
            showTooltip: true,
          ),
        ),
      ],
    );
  }
}

// Bar Chart Example
class BarChartExample extends StatelessWidget {
  BarChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final data = [
      const BarChartData(value: 20, label: 'Product A'),
      const BarChartData(value: 35, label: 'Product B'),
      const BarChartData(value: 25, label: 'Product C'),
      const BarChartData(value: 40, label: 'Product D'),
      const BarChartData(value: 30, label: 'Product E'),
    ];

    const style = BarChartStyle(
      barColor: Colors.green,
      gradientEffect: true,
      gradientColors: [Colors.green, Colors.lightGreen],
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'Product Sales Comparison',
          _chartKey,
          onExportSvg: () => _exportBarChartSvg(context, data, style, 'Product Sales Comparison'),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: _chartKey,
          child: MaterialBarChart(
            data: data,
            width: 350,
            height: 300,
            style: style,
            showTooltip: true,
          ),
        ),
      ],
    );
  }
}

// Animated Bar Chart Example - Demonstrates new sequential animation features
class AnimatedBarChartExample extends StatelessWidget {
  AnimatedBarChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Create bar data with custom animation configurations
    final data = [
      // First bar: scales up first (order 0)
      BarChartData(
        value: 20,
        label: 'Product A',
        color: Colors.blue,
        animationConfig: const BarAnimationConfig(
          animationOrder: 0,
          animationType: BarAnimationType.scaleUp,
          animationTrigger: BarAnimationTrigger.immediate,
          duration: Duration(milliseconds: 800),
        ),
      ),
      // Second bar: slides up after a 100ms delay from first
      BarChartData(
        value: 35,
        label: 'Product B',
        color: Colors.red,
        animationConfig: const BarAnimationConfig(
          animationOrder: 2,
          animationType: BarAnimationType.slideUp,
          animationTrigger: BarAnimationTrigger.afterDelay,
          duration: Duration(milliseconds: 800),
          delayBeforeNext: Duration(milliseconds: 100),
        ),
      ),
      // Third bar: fades in at the same time as second bar
      BarChartData(
        value: 25,
        label: 'Product C',
        color: Colors.green,
        animationConfig: const BarAnimationConfig(
          animationOrder: 1,
          animationType: BarAnimationType.fadeIn,
          animationTrigger: BarAnimationTrigger.immediate,
          duration: Duration(milliseconds: 800),
        ),
      ),
      // Fourth bar: bounces in after 100ms delay
      BarChartData(
        value: 40,
        label: 'Product D',
        color: Colors.orange,
        animationConfig: const BarAnimationConfig(
          animationOrder: 3,
          animationType: BarAnimationType.bounce,
          animationTrigger: BarAnimationTrigger.afterDelay,
          duration: Duration(milliseconds: 800),
          delayBeforeNext: Duration(milliseconds: 100),
        ),
      ),
      // Fifth bar: slides down with custom curve
      BarChartData(
        value: 30,
        label: 'Product E',
        color: Colors.purple,
        animationConfig: const BarAnimationConfig(
          animationOrder: 4,
          animationType: BarAnimationType.slideDown,
          animationTrigger: BarAnimationTrigger.afterPrevious,
          duration: Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          delayBeforeNext: Duration(milliseconds: 100),
        ),
      ),
    ];

    const style = BarChartStyle(
      barSpacing: 0.2,
      gradientEffect: false,
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'Animated Bar Chart - Sequential Animation Demo',
          _chartKey,
          onExportSvg: () => _exportBarChartSvg(context, data, style, 'Animated Sales'),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: _chartKey,
          child: MaterialBarChart(
            data: data,
            width: 350,
            height: 300,
            style: style,
            showTooltip: true,
          ),
        ),
      ],
    );
  }
}

/// Example demonstrating bar chart animations with manual triggers
class ManuallyTriggeredBarChartExample extends StatefulWidget {
  const ManuallyTriggeredBarChartExample({Key? key}) : super(key: key);

  @override
  State<ManuallyTriggeredBarChartExample> createState() => _ManuallyTriggeredBarChartExampleState();
}

class _ManuallyTriggeredBarChartExampleState extends State<ManuallyTriggeredBarChartExample> {
  final GlobalKey<MaterialBarChartState> _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manual Trigger Bar Chart Animations',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Click the buttons to trigger bar animations independently.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        // Trigger buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _chartKey.currentState?.triggerAnimation(0),
              child: const Text('Animate Bar 1'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _chartKey.currentState?.triggerAnimation(1),
              child: const Text('Animate Bar 2'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _chartKey.currentState?.triggerAnimation(2),
              child: const Text('Animate Bar 3'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _chartKey.currentState?.triggerAnimation(3),
              child: const Text('Animate Bar 4'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Reset buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _chartKey.currentState?.resetAnimation(0),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
              child: const Text('Reset Bar 1'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _chartKey.currentState?.resetAnimation(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
              child: const Text('Reset Bar 2'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _chartKey.currentState?.resetAnimation(2),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
              child: const Text('Reset Bar 3'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _chartKey.currentState?.resetAnimation(3),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
              child: const Text('Reset Bar 4'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 350,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: MaterialBarChart(
            key: _chartKey,
            data: [
              BarChartData(
                value: 20,
                label: 'Product A',
                color: Colors.blue,
                animationConfig: const BarAnimationConfig(
                  animationOrder: 0,
                  animationType: BarAnimationType.scaleUp,
                  animationTrigger: BarAnimationTrigger.manual,
                  duration: Duration(milliseconds: 800),
                ),
              ),
              BarChartData(
                value: 35,
                label: 'Product B',
                color: Colors.red,
                animationConfig: const BarAnimationConfig(
                  animationOrder: 1,
                  animationType: BarAnimationType.slideUp,
                  animationTrigger: BarAnimationTrigger.manual,
                  duration: Duration(milliseconds: 800),
                ),
              ),
              BarChartData(
                value: 25,
                label: 'Product C',
                color: Colors.green,
                animationConfig: const BarAnimationConfig(
                  animationOrder: 2,
                  animationType: BarAnimationType.fadeIn,
                  animationTrigger: BarAnimationTrigger.manual,
                  duration: Duration(milliseconds: 800),
                ),
              ),
              BarChartData(
                value: 40,
                label: 'Product D',
                color: Colors.orange,
                animationConfig: const BarAnimationConfig(
                  animationOrder: 3,
                  animationType: BarAnimationType.bounce,
                  animationTrigger: BarAnimationTrigger.manual,
                  duration: Duration(milliseconds: 800),
                ),
              ),
            ],
            width: 600,
            height: 300,
            style: const BarChartStyle(
              barSpacing: 0.2,
              gradientEffect: true,
              gradientColors: [Colors.blue, Colors.lightBlue],
            ),
            showValues: true,
            showGrid: true,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// Grouped Bar Chart Example
class GroupedBarChartExample extends StatelessWidget {
  GroupedBarChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Multiple data series with the same labels, grouped by quarter
    final data = [
      // Q1 Sales
      const BarChartData(value: 20, label: 'Q1', color: Colors.blue),
      const BarChartData(value: 25, label: 'Q1', color: Colors.red),
      const BarChartData(value: 18, label: 'Q1', color: Colors.green),
      // Q2 Sales
      const BarChartData(value: 30, label: 'Q2', color: Colors.blue),
      const BarChartData(value: 35, label: 'Q2', color: Colors.red),
      const BarChartData(value: 28, label: 'Q2', color: Colors.green),
      // Q3 Sales
      const BarChartData(value: 40, label: 'Q3', color: Colors.blue),
      const BarChartData(value: 38, label: 'Q3', color: Colors.red),
      const BarChartData(value: 32, label: 'Q3', color: Colors.green),
    ];

    const style = BarChartStyle(
      barSpacing: 0.1,
      groupByLabel: true, // Enable grouping by label
      gradientEffect: false,
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'Quarterly Sales by Division (Grouped)',
          _chartKey,
          onExportSvg: () => _exportBarChartSvg(context, data, style, 'Quarterly Sales'),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: _chartKey,
          child: MaterialBarChart(
            data: data,
            width: 400,
            height: 300,
            style: style,
            showTooltip: true,
          ),
        ),
      ],
    );
  }
}

// Pie Chart Example
class PieChartExample extends StatelessWidget {
  PieChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final data = [
      const PieChartData(value: 30, label: 'Mobile', color: Colors.blue),
      const PieChartData(value: 25, label: 'Desktop', color: Colors.red),
      const PieChartData(value: 20, label: 'Tablet', color: Colors.green),
      const PieChartData(value: 15, label: 'Watch', color: Colors.orange),
      const PieChartData(value: 10, label: 'Other', color: Colors.purple),
    ];

    const style = PieChartStyle(
      chartAlignment: ChartAlignment.topLeft,
      holeRadius: 0.5,
      backgroundColor: Colors.transparent,
      showLegend: true,
      legendPosition: PieChartLegendPosition.bottom,
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'Device Usage Distribution',
          _chartKey,
          onExportSvg: () => _exportPieChartSvg(context, data, style, 'Device Usage Distribution'),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
            key: _chartKey,
            child: MaterialPieChart(
              data: data,
              width: 350,
              height: 300,
              style: style,
            )),
      ],
    );
  }
}

/// Example demonstrating pie chart slice animations with pop-out effects
class PieChartAnimationExample extends StatefulWidget {
  const PieChartAnimationExample({Key? key}) : super(key: key);

  @override
  State<PieChartAnimationExample> createState() => _PieChartAnimationExampleState();
}

class _PieChartAnimationExampleState extends State<PieChartAnimationExample> {
  final GlobalKey<MaterialPieChartState> _chartKey1 = GlobalKey();
  final GlobalKey<MaterialPieChartState> _chartKey2 = GlobalKey();
  final GlobalKey<MaterialPieChartState> _chartKey3 = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Example 2: Manual Trigger Animations
        _buildSectionTitle('2. Manual Trigger Animations'),
        _buildDescription(
          'Click the buttons to trigger slice animations independently.',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _chartKey2.currentState?.triggerAnimation(0),
              child: const Text('Animate Slice 1'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _chartKey2.currentState?.triggerAnimation(1),
              child: const Text('Animate Slice 2'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _chartKey2.currentState?.triggerAnimation(2),
              child: const Text('Animate Slice 3'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _chartKey2.currentState?.resetAnimation(0),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
              child: const Text('Reset Slice 1'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _chartKey2.currentState?.resetAnimation(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
              child: const Text('Reset Slice 2'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _chartKey2.currentState?.resetAnimation(2),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
              child: const Text('Reset Slice 3'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 400,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: MaterialPieChart(
            key: _chartKey2,
            data: [
              PieChartData(
                value: 40,
                label: 'Marketing',
                color: Colors.purple,
                animationConfig: const PieSliceAnimationConfig(
                  animationOrder: 0,
                  animationTrigger: SliceAnimationTrigger.manual,
                  duration: Duration(milliseconds: 800),
                  popOutOffset: 1.05,
                ),
              ),
              PieChartData(
                value: 30,
                label: 'Sales',
                color: Colors.teal,
                animationConfig: const PieSliceAnimationConfig(
                  animationOrder: 1,
                  animationTrigger: SliceAnimationTrigger.manual,
                  duration: Duration(milliseconds: 800),
                  popOutOffset: 1.05,
                ),
              ),
              PieChartData(
                value: 30,
                label: 'Operations',
                color: Colors.amber,
                animationConfig: const PieSliceAnimationConfig(
                  animationOrder: 2,
                  animationTrigger: SliceAnimationTrigger.manual,
                  duration: Duration(milliseconds: 800),
                  popOutOffset: 1.05,
                ),
              ),
            ],
            width: 600,
            height: 400,
            style: const PieChartStyle(
              showLegend: false,
              legendPosition: PieChartLegendPosition.bottom,
              holeRadius: 0.5,
              sliceAnimationsEnabled: true,
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDescription(String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        description,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}

// Population Pyramid Example
class PopulationChartExample extends StatelessWidget {
  PopulationChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final data = [
      const PopulationPyramidData(
        ageGroup: '80+',
        leftPopulation: 800000,
        rightPopulation: 1100000,
      ),
      const PopulationPyramidData(
        ageGroup: '75-79',
        leftPopulation: 1100000,
        rightPopulation: 1300000,
      ),
      const PopulationPyramidData(
        ageGroup: '70-74',
        leftPopulation: 1700000,
        rightPopulation: 1900000,
      ),
      const PopulationPyramidData(
        ageGroup: '65-69',
        leftPopulation: 2400000,
        rightPopulation: 2600000,
      ),
      const PopulationPyramidData(
        ageGroup: '60-64',
        leftPopulation: 3200000,
        rightPopulation: 3400000,
      ),
      const PopulationPyramidData(
        ageGroup: '55-59',
        leftPopulation: 4100000,
        rightPopulation: 4200000,
      ),
      const PopulationPyramidData(
        ageGroup: '50-54',
        leftPopulation: 4900000,
        rightPopulation: 5000000,
      ),
      const PopulationPyramidData(
        ageGroup: '45-49',
        leftPopulation: 5600000,
        rightPopulation: 5500000,
      ),
      const PopulationPyramidData(
        ageGroup: '40-44',
        leftPopulation: 6200000,
        rightPopulation: 6100000,
      ),
      const PopulationPyramidData(
        ageGroup: '35-39',
        leftPopulation: 6900000,
        rightPopulation: 6800000,
      ),
      const PopulationPyramidData(
        ageGroup: '30-34',
        leftPopulation: 7400000,
        rightPopulation: 7200000,
      ),
      const PopulationPyramidData(
        ageGroup: '25-29',
        leftPopulation: 7800000,
        rightPopulation: 7500000,
      ),
      const PopulationPyramidData(
        ageGroup: '20-24',
        leftPopulation: 7500000,
        rightPopulation: 7200000,
      ),
      const PopulationPyramidData(
        ageGroup: '15-19',
        leftPopulation: 7100000,
        rightPopulation: 6800000,
      ),
      const PopulationPyramidData(
        ageGroup: '10-14',
        leftPopulation: 6800000,
        rightPopulation: 6500000,
      ),
      const PopulationPyramidData(
        ageGroup: '5-9',
        leftPopulation: 6500000,
        rightPopulation: 6200000,
      ),
      const PopulationPyramidData(
        ageGroup: '0-4',
        leftPopulation: 6200000,
        rightPopulation: 5900000,
      ),
    ];

    const style = PopulationPyramidStyle(
      backgroundColor: Colors.white,
      leftColor: Color(0xFF4A90E2),
      rightColor: Color(0xFFED6D91),
      labelColor: Colors.black87,
      valueColor: Colors.black54,
      labelFontSize: 11.0,
      valueFontSize: 9.0,
      labelFontWeight: FontWeight.w600,
      valueFontWeight: FontWeight.w400,
      showGridLines: false,
      gridLineColor: Colors.grey,
      gridLineWidth: 0.5,
      verticalGridLines: 4,
      horizontalGridLines: 0,
      showLegend: true,
      showValues: true,
      showPercentage: true,
      centerGap: 80.0,
      legendPosition: PyramidLegendPosition.bottomCenter,
      legendGapFromChart: 0.0,
      barValueGap: 12.0,
      legendItemSpacing: 50.0,
      legendSquareSize: 14.0,
      showLegendSquares: true,
      legendLeftLabel: 'Group A',
      legendRightLabel: 'Group B',
      legendTextStyle: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'USA Population Pyramid',
          _chartKey,
          onExportSvg: () => _exportPopulationPyramidSvg(
            context,
            data,
            style,
            'USA Population Pyramid',
          ),
          onExportPdf: () => _exportPopulationPyramidPdf(
            context,
            data,
            style,
            'USA Population Pyramid',
          ),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: _chartKey,
          child: MaterialPopulationPyramid(
            data: data,
            width: 600,
            animationDuration: Duration(milliseconds: 1000),
            height: 500,
            style: style,
            padding: const EdgeInsets.all(40.0),
          ),
        ),
      ],
    );
  }
}

// Area Chart Example
class AreaChartExample extends StatelessWidget {
  AreaChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

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

    const style = AreaChartStyle(
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
        strokeWidth: 2.0,
        dashPattern: [5.0, 3.0],
      ),
      xSpanSlots: 8,
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'Quarterly Revenue Trend with Key Events',
          _chartKey,
          onExportSvg: () => _exportAreaChartSvg(context, series, style, 'Quarterly Revenue Trend'),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: _chartKey,
          child: MaterialAreaChart(
            style: style,
            series: series,
            width: 350,
            height: 250,
          ),
        ),
      ],
    );
  }
}

// Animated Area Chart Example - Demonstrates sequential area animation features
class AnimatedAreaChartExample extends StatelessWidget {
  AnimatedAreaChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final series = [
      AreaChartSeries(
        name: 'Product A',
        dataPoints: const [
          AreaChartData(value: 10, label: 'Jan', segmentAnimationOrder: 0),
          AreaChartData(value: 25, label: 'Feb', segmentAnimationOrder: 0),
          AreaChartData(value: 20, label: 'Mar', segmentAnimationOrder: 0),
          AreaChartData(value: 35, label: 'Apr', segmentAnimationOrder: 0),
          AreaChartData(value: 40, label: 'May', segmentAnimationOrder: 1),
          AreaChartData(value: 38, label: 'Jun', segmentAnimationOrder: 2),
        ],
        color: Colors.blue,
        gradientColor: Colors.blue.withValues(alpha: 0),
        animationConfig: const AreaAnimationConfig(
          animationOrder: 0,
          animationType: AreaAnimationType.drawLine,
          animationTrigger: AreaAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1000),
        ),
      ),
      AreaChartSeries(
        name: 'Product B',
        dataPoints: const [
          AreaChartData(value: 5, label: 'Jan', segmentAnimationOrder: 0),
          AreaChartData(value: 12, label: 'Feb', segmentAnimationOrder: 0),
          AreaChartData(value: 18, label: 'Mar', segmentAnimationOrder: 0),
          AreaChartData(value: 22, label: 'Apr', segmentAnimationOrder: 0),
          AreaChartData(value: 28, label: 'May', segmentAnimationOrder: 1),
          AreaChartData(value: 30, label: 'Jun', segmentAnimationOrder: 2),
        ],
        color: Colors.red,
        gradientColor: Colors.red.withValues(alpha: 0),
        animationConfig: const AreaAnimationConfig(
          animationOrder: 1,
          animationType: AreaAnimationType.fadeIn,
          animationTrigger: AreaAnimationTrigger.afterDelay,
          duration: Duration(milliseconds: 900),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
      ),
      AreaChartSeries(
        name: 'Product C',
        dataPoints: const [
          AreaChartData(value: 15, label: 'Jan', segmentAnimationOrder: 0),
          AreaChartData(value: 18, label: 'Feb', segmentAnimationOrder: 0),
          AreaChartData(value: 22, label: 'Mar', segmentAnimationOrder: 0),
          AreaChartData(value: 28, label: 'Apr', segmentAnimationOrder: 0),
          AreaChartData(value: 34, label: 'May', segmentAnimationOrder: 1),
          AreaChartData(value: 36, label: 'Jun', segmentAnimationOrder: 2),
        ],
        color: Colors.green,
        gradientColor: Colors.green.withValues(alpha: 0),
        animationConfig: const AreaAnimationConfig(
          animationOrder: 2,
          animationType: AreaAnimationType.slideUp,
          animationTrigger: AreaAnimationTrigger.afterDelay,
          duration: Duration(milliseconds: 900),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
      ),
    ];

    final style = AreaChartStyle(
      colors: const [Colors.blue, Colors.red, Colors.green],
      showPoints: true,
      showGrid: true,
      forceYAxisFromZero: true,
      defaultAnimationTrigger: AreaAnimationTrigger.afterDelay,
      defaultDelayBeforeNext: const Duration(milliseconds: 150),
      segmentAnimationConfigs: {
        1: const SegmentAnimationConfig(
          segmentAnimationOrder: 1,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: AreaAnimationTrigger.immediate,
          duration: Duration(milliseconds: 600),
          delayBeforeNext: Duration(milliseconds: 100),
        ),
        2: const SegmentAnimationConfig(
          segmentAnimationOrder: 2,
          animationType: SegmentAnimationType.slideUp,
          animationTrigger: AreaAnimationTrigger.afterPrevious,
          duration: Duration(milliseconds: 600),
          delayBeforeNext: Duration(milliseconds: 100),
        ),
      },
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'Animated Area Chart - Sequential Animation Demo',
          _chartKey,
          onExportSvg: () => _exportAreaChartSvg(context, series, style, 'Animated Area Trends'),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: _chartKey,
          child: MaterialAreaChart(
            series: series,
            width: 350,
            height: 250,
            style: style,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// Animated Area Chart with Segment Animations
class AnimatedAreaSegmentChartExample extends StatelessWidget {
  AnimatedAreaSegmentChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final series = [
      AreaChartSeries(
        name: 'Sales',
        dataPoints: const [
          AreaChartData(value: 12, label: 'Jan', segmentAnimationOrder: 0),
          AreaChartData(value: 20, label: 'Feb', segmentAnimationOrder: 0),
          AreaChartData(value: 18, label: 'Mar', segmentAnimationOrder: 0),
          AreaChartData(value: 28, label: 'Apr', segmentAnimationOrder: 1),
          AreaChartData(value: 35, label: 'May', segmentAnimationOrder: 1),
          AreaChartData(value: 33, label: 'Jun', segmentAnimationOrder: 2),
          AreaChartData(value: 40, label: 'Jul', segmentAnimationOrder: 3),
          AreaChartData(value: 44, label: 'Aug', segmentAnimationOrder: 3),
        ],
        color: Colors.blue,
        gradientColor: Colors.blue.withValues(alpha: 0),
        animationConfig: const AreaAnimationConfig(
          animationOrder: 0,
          animationType: AreaAnimationType.drawLine,
          animationTrigger: AreaAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1000),
        ),
      ),
      AreaChartSeries(
        name: 'Profit',
        dataPoints: const [
          AreaChartData(value: 8, label: 'Jan', segmentAnimationOrder: 0),
          AreaChartData(value: 12, label: 'Feb', segmentAnimationOrder: 0),
          AreaChartData(value: 14, label: 'Mar', segmentAnimationOrder: 0),
          AreaChartData(value: 19, label: 'Apr', segmentAnimationOrder: 1),
          AreaChartData(value: 24, label: 'May', segmentAnimationOrder: 1),
          AreaChartData(value: 26, label: 'Jun', segmentAnimationOrder: 2),
          AreaChartData(value: 31, label: 'Jul', segmentAnimationOrder: 3),
          AreaChartData(value: 34, label: 'Aug', segmentAnimationOrder: 3),
        ],
        color: Colors.green,
        gradientColor: Colors.green.withValues(alpha: 0),
        animationConfig: const AreaAnimationConfig(
          animationOrder: 0,
          animationType: AreaAnimationType.fadeIn,
          animationTrigger: AreaAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1000),
        ),
      ),
    ];

    final style = AreaChartStyle(
      colors: const [Colors.blue, Colors.green],
      showPoints: true,
      showGrid: true,
      forceYAxisFromZero: true,
      defaultAnimationTrigger: AreaAnimationTrigger.afterDelay,
      defaultDelayBeforeNext: const Duration(milliseconds: 120),
      segmentAnimationConfigs: {
        1: const SegmentAnimationConfig(
          segmentAnimationOrder: 1,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: AreaAnimationTrigger.immediate,
          duration: Duration(milliseconds: 600),
          delayBeforeNext: Duration(milliseconds: 120),
        ),
        2: const SegmentAnimationConfig(
          segmentAnimationOrder: 2,
          animationType: SegmentAnimationType.slideUp,
          animationTrigger: AreaAnimationTrigger.afterPrevious,
          duration: Duration(milliseconds: 650),
          delayBeforeNext: Duration(milliseconds: 120),
        ),
        3: const SegmentAnimationConfig(
          segmentAnimationOrder: 3,
          animationType: SegmentAnimationType.fadeIn,
          animationTrigger: AreaAnimationTrigger.afterPrevious,
          duration: Duration(milliseconds: 700),
          delayBeforeNext: Duration(milliseconds: 120),
        ),
      },
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'Animated Area Chart - Segment Animation Demo',
          _chartKey,
          onExportSvg: () => _exportAreaChartSvg(context, series, style, 'Animated Area Segment Demo'),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: _chartKey,
          child: MaterialAreaChart(
            series: series,
            width: 350,
            height: 250,
            style: style,
          ),
        ),
      ],
    );
  }
}

// Animated Area Chart with Manual Triggers
class AnimatedAreaManualTriggerExample extends StatefulWidget {
  AnimatedAreaManualTriggerExample({super.key});

  @override
  State<AnimatedAreaManualTriggerExample> createState() => _AnimatedAreaManualTriggerExampleState();
}

class _AnimatedAreaManualTriggerExampleState extends State<AnimatedAreaManualTriggerExample> {
  final GlobalKey<MaterialAreaChartState> _chartKey = GlobalKey<MaterialAreaChartState>();

  @override
  Widget build(BuildContext context) {
    final series = [
      AreaChartSeries(
        name: 'Revenue',
        dataPoints: const [
          AreaChartData(value: 15, label: 'Q1', segmentAnimationOrder: 0),
          AreaChartData(value: 22, label: 'Q2', segmentAnimationOrder: 0),
          AreaChartData(value: 28, label: 'Q3', segmentAnimationOrder: 1),
          AreaChartData(value: 35, label: 'Q4', segmentAnimationOrder: 2),
        ],
        color: Colors.blue,
        gradientColor: Colors.blue.withValues(alpha: 0),
        animationConfig: const AreaAnimationConfig(
          animationOrder: 0,
          animationType: AreaAnimationType.fadeIn,
          animationTrigger: AreaAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1200),
        ),
      ),
      AreaChartSeries(
        name: 'Expenses',
        dataPoints: const [
          AreaChartData(value: 8, label: 'Q1', segmentAnimationOrder: 0),
          AreaChartData(value: 12, label: 'Q2', segmentAnimationOrder: 0),
          AreaChartData(value: 16, label: 'Q3', segmentAnimationOrder: 1),
          AreaChartData(value: 20, label: 'Q4', segmentAnimationOrder: 2),
        ],
        color: Colors.red,
        gradientColor: Colors.red.withValues(alpha: 0),
        animationConfig: const AreaAnimationConfig(
          animationOrder: 0,
          animationType: AreaAnimationType.fadeIn,
          animationTrigger: AreaAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1200),
        ),
      ),
    ];

    final style = AreaChartStyle(
      colors: const [Colors.blue, Colors.red],
      showPoints: true,
      showGrid: true,
      forceYAxisFromZero: true,
      defaultAnimationTrigger: AreaAnimationTrigger.manual,
      segmentAnimationConfigs: {
        1: const SegmentAnimationConfig(
          segmentAnimationOrder: 1,
          animationType: SegmentAnimationType.fadeIn,
          animationTrigger: AreaAnimationTrigger.manual,
          duration: Duration(milliseconds: 800),
        ),
        2: const SegmentAnimationConfig(
          segmentAnimationOrder: 2,
          animationType: SegmentAnimationType.fadeIn,
          animationTrigger: AreaAnimationTrigger.manual,
          duration: Duration(milliseconds: 800),
        ),
      },
    );

    return Column(
      children: [
        const Text(
          'Area Chart - Manual Trigger Demo (FadeIn)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 300,
          width: 350,
          child: MaterialAreaChart(
            key: _chartKey,
            series: series,
            width: 350,
            height: 250,
            style: style,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _chartKey.currentState?.triggerAnimation(1);
              },
              child: const Text('Trigger Segment 1 FadeIn'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                _chartKey.currentState?.triggerAnimation(2);
              },
              child: const Text('Trigger Segment 2 (FadeIn)'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Example with line animation followed by 3 buttons to trigger segment animations
class AnimatedAreaSegmentTriggersExample extends StatefulWidget {
  const AnimatedAreaSegmentTriggersExample({super.key});

  @override
  State<AnimatedAreaSegmentTriggersExample> createState() => _AnimatedAreaSegmentTriggersExampleState();
}

class _AnimatedAreaSegmentTriggersExampleState extends State<AnimatedAreaSegmentTriggersExample> {
  final GlobalKey<MaterialAreaChartState> _chartKey = GlobalKey<MaterialAreaChartState>();

  void _triggerSegment(int segmentOrder) {
    final state = _chartKey.currentState;
    if (state != null) {
      state.triggerAnimation(segmentOrder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = [
      const AreaChartData(value: 10, label: 'Jan', segmentAnimationOrder: 0),
      const AreaChartData(value: 20, label: 'Feb', segmentAnimationOrder: 0),
      const AreaChartData(value: 15, label: 'Mar', segmentAnimationOrder: 0),
      const AreaChartData(value: 25, label: 'Apr', segmentAnimationOrder: 1),
      const AreaChartData(value: 30, label: 'May', segmentAnimationOrder: 1),
      const AreaChartData(value: 28, label: 'Jun', segmentAnimationOrder: 1),
      const AreaChartData(value: 35, label: 'Jul', segmentAnimationOrder: 2),
      const AreaChartData(value: 40, label: 'Aug', segmentAnimationOrder: 2),
      const AreaChartData(value: 38, label: 'Sep', segmentAnimationOrder: 2),
    ];

    final series = [
      AreaChartSeries(
        name: 'Growth Metrics',
        dataPoints: data,
        color: Colors.blue,
        gradientColor: Colors.blue.withValues(alpha: 0),
        animationConfig: const AreaAnimationConfig(
          animationOrder: 0,
          animationType: AreaAnimationType.drawLine,
          animationTrigger: AreaAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1500),
        ),
      ),
    ];

    final style = AreaChartStyle(
      showGrid: true,
      forceYAxisFromZero: true,
      defaultAnimationTrigger: AreaAnimationTrigger.manual,
      segmentAnimationConfigs: {
        1: SegmentAnimationConfig(
          segmentAnimationOrder: 1,
          animationType: SegmentAnimationType.slideUp,
          duration: const Duration(milliseconds: 800),
          animationTrigger: AreaAnimationTrigger.manual,
        ),
        2: SegmentAnimationConfig(
          segmentAnimationOrder: 2,
          animationType: SegmentAnimationType.fadeIn,
          duration: const Duration(milliseconds: 800),
          animationTrigger: AreaAnimationTrigger.manual,
        ),
      },
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Line Animation + Segment Triggers',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MaterialAreaChart(
          key: _chartKey,
          style: style,
          series: series,
          width: 350,
          height: 250,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _chartKey.currentState?.triggerAnimation(1);
              },
              child: const Text('Trigger Segment 1 SlideUp'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                _chartKey.currentState?.triggerAnimation(2);
              },
              child: const Text('Trigger Segment 2 (FadeIn)'),
            ),
          ],
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

    const style = MultiLineChartStyle(
      colors: [Colors.blue, Colors.green, Colors.red],
      showLegend: true,
    );

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Sales vs Profit Comparison',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Export SVG',
              icon: const Icon(Icons.image),
              onPressed: () => _exportMultiLineChartSvg(context, series, style, 'Sales vs Profit Comparison'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        MultiLineChart(
          series: series,
          style: style,
          height: 300,
          width: 350,
        ),
      ],
    );
  }
}

// Animated Multi-Line Chart Example
class AnimatedMultiLineChartExample extends StatelessWidget {
  AnimatedMultiLineChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Create line series with custom animation configurations
    final series = [
      ChartSeries(
        name: 'Product A',
        dataPoints: const [
          ChartDataPoint(value: 10, label: 'Jan'),
          ChartDataPoint(value: 25, label: 'Feb'),
          ChartDataPoint(value: 20, label: 'Mar'),
          ChartDataPoint(value: 35, label: 'Apr'),
        ],
        color: Colors.blue,
        animationConfig: const LineAnimationConfig(
          animationOrder: 0,
          animationType: LineAnimationType.drawLine,
          animationTrigger: LineAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1000),
        ),
      ),
      ChartSeries(
        name: 'Product B',
        dataPoints: const [
          ChartDataPoint(value: 5, label: 'Jan'),
          ChartDataPoint(value: 12, label: 'Feb'),
          ChartDataPoint(value: 18, label: 'Mar'),
          ChartDataPoint(value: 22, label: 'Apr'),
        ],
        color: Colors.red,
        animationConfig: const LineAnimationConfig(
          animationOrder: 1,
          animationType: LineAnimationType.fadeIn,
          animationTrigger: LineAnimationTrigger.afterDelay,
          duration: Duration(milliseconds: 900),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
      ),
      ChartSeries(
        name: 'Product C',
        dataPoints: const [
          ChartDataPoint(value: 15, label: 'Jan'),
          ChartDataPoint(value: 18, label: 'Feb'),
          ChartDataPoint(value: 22, label: 'Mar'),
          ChartDataPoint(value: 28, label: 'Apr'),
        ],
        color: Colors.green,
        animationConfig: const LineAnimationConfig(
          animationOrder: 2,
          animationType: LineAnimationType.drawLine,
          animationTrigger: LineAnimationTrigger.afterDelay,
          duration: Duration(milliseconds: 900),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
      ),
    ];

    final style = MultiLineChartStyle(
      colors: const [Colors.blue, Colors.red, Colors.green],
      showLegend: true,
      defaultAnimationType: LineAnimationType.drawLine,
      defaultAnimationTrigger: LineAnimationTrigger.afterDelay,
      defaultAnimationDuration: const Duration(milliseconds: 900),
      defaultDelayBeforeNext: const Duration(milliseconds: 150),
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'Animated Multi-Line Chart - Sequential Animation Demo',
          _chartKey,
          onExportSvg: () => _exportMultiLineChartSvg(context, series, style, 'Animated Product Trends'),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: _chartKey,
          child: MultiLineChart(
            series: series,
            style: style,
            height: 300,
            width: 350,
          ),
        ),
      ],
    );
  }
}

// Animated Multi-Line Chart with Segment Animations
class AnimatedSegmentMultiLineChartExample extends StatelessWidget {
  AnimatedSegmentMultiLineChartExample({super.key});

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Create line series with progressive segment animations
    // Segment 0 (Jan-Apr): Drawn during line animation phase (no explicit config)
    // Segment 1 (Apr-May): Revealed after line animation completes
    // Segment 2 (May-Jun): Revealed after segment 1 completes
    final series = [
      ChartSeries(
        name: 'Line 1',
        dataPoints: [
          const ChartDataPoint(value: 10, label: 'Jan', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 25, label: 'Feb', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 20, label: 'Mar', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 35, label: 'Apr', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 40, label: 'May', segmentAnimationOrder: 1),
          const ChartDataPoint(value: 38, label: 'Jun', segmentAnimationOrder: 2),
        ],
        color: Colors.blue,
        animationConfig: const LineAnimationConfig(
          animationOrder: 0,
          animationType: LineAnimationType.drawLine,
          animationTrigger: LineAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1000),
        ),
      ),
      ChartSeries(
        name: 'Line 2',
        dataPoints: [
          const ChartDataPoint(value: 5, label: 'Jan', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 12, label: 'Feb', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 18, label: 'Mar', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 22, label: 'Apr', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 28, label: 'May', segmentAnimationOrder: 1),
          const ChartDataPoint(value: 30, label: 'Jun', segmentAnimationOrder: 2),
        ],
        color: Colors.red,
        animationConfig: const LineAnimationConfig(
          animationOrder: 0,
          animationType: LineAnimationType.fadeIn,
          animationTrigger: LineAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1000),
        ),
      ),
    ];

    final style = MultiLineChartStyle(
      colors: const [Colors.blue, Colors.red],
      showLegend: true,
      // Progressive segment animation configurations
      // Segment 0 has NO config, so it's drawn during line animation phase
      // Segments 1 and 2 have explicit configs, so they animate separately AFTER line completes
      segmentAnimationConfigs: {
        1: const SegmentAnimationConfig(
          segmentAnimationOrder: 1,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: LineAnimationTrigger.immediate,
          duration: Duration(milliseconds: 600),
          delayBeforeNext: Duration(milliseconds: 100),
        ),
        2: const SegmentAnimationConfig(
          segmentAnimationOrder: 2,
          animationType: SegmentAnimationType.slideUp,
          animationTrigger: LineAnimationTrigger.afterPrevious,
          duration: Duration(milliseconds: 600),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
      },
    );

    return Column(
      children: [
        _buildExportHeader(
          context,
          'Animated Multi-Line Chart - Segment Animations Demo',
          _chartKey,
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: _chartKey,
          child: MultiLineChart(
            series: series,
            style: style,
            height: 300,
            width: 350,
          ),
        ),
      ],
    );
  }
}

// Manual Trigger Multi-Line Chart Example
class AnimatedSegmentWithManualTriggerExample extends StatefulWidget {
  AnimatedSegmentWithManualTriggerExample({super.key});

  @override
  State<AnimatedSegmentWithManualTriggerExample> createState() => _AnimatedSegmentWithManualTriggerExampleState();
}

class _AnimatedSegmentWithManualTriggerExampleState extends State<AnimatedSegmentWithManualTriggerExample> {
  final GlobalKey<MultiLineChartState> _chartKey = GlobalKey<MultiLineChartState>();

  @override
  Widget build(BuildContext context) {
    // Create line series with THREE animation orders that require manual triggers
    // Order 0: Line animation phase (complete with segment 0)
    // Order 1: Segment 1 animation (triggered by button)
    // Order 2: Segment 2 animation (triggered by button)
    final series = [
      ChartSeries(
        name: 'Product A',
        dataPoints: [
          const ChartDataPoint(value: 10, label: 'Jan', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 25, label: 'Feb', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 20, label: 'Mar', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 35, label: 'Apr', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 40, label: 'May', segmentAnimationOrder: 1),
          const ChartDataPoint(value: 38, label: 'Jun', segmentAnimationOrder: 2),
        ],
        color: Colors.blue,
        animationConfig: const LineAnimationConfig(
          animationOrder: 0,
          animationType: LineAnimationType.drawLine,
          animationTrigger: LineAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1200),
        ),
      ),
      ChartSeries(
        name: 'Product B',
        dataPoints: [
          const ChartDataPoint(value: 5, label: 'Jan', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 12, label: 'Feb', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 18, label: 'Mar', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 22, label: 'Apr', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 28, label: 'May', segmentAnimationOrder: 1),
          const ChartDataPoint(value: 30, label: 'Jun', segmentAnimationOrder: 2),
        ],
        color: Colors.red,
        animationConfig: const LineAnimationConfig(
          animationOrder: 0,
          animationType: LineAnimationType.fadeIn,
          animationTrigger: LineAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1200),
        ),
      ),
    ];

    final style = MultiLineChartStyle(
      colors: const [Colors.blue, Colors.red],
      showLegend: true,
      segmentAnimationConfigs: {
        1: const SegmentAnimationConfig(
          segmentAnimationOrder: 1,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: LineAnimationTrigger.manual,
          duration: Duration(milliseconds: 700),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
        2: const SegmentAnimationConfig(
          segmentAnimationOrder: 2,
          animationType: SegmentAnimationType.slideUp,
          animationTrigger: LineAnimationTrigger.manual,
          duration: Duration(milliseconds: 700),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
      },
    );

    return Column(
      children: [
        const Text(
          'Animated Multi-Line Chart - Manual Trigger Demo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 300,
          width: 350,
          child: MultiLineChart(
            key: _chartKey,
            series: series,
            style: style,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Trigger segment 1 animation manually
                _chartKey.currentState?.triggerAnimation(1);
              },
              child: const Text('Add May Data'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                // Trigger segment 2 animation manually
                _chartKey.currentState?.triggerAnimation(2);
              },
              child: const Text('Add Jun Data'),
            ),
          ],
        ),
      ],
    );
  }
}

// Multi-Segment with Progressive Manual Triggers Example
class MultiSegmentWithManualTriggersExample extends StatefulWidget {
  MultiSegmentWithManualTriggersExample({super.key});

  @override
  State<MultiSegmentWithManualTriggersExample> createState() => _MultiSegmentWithManualTriggersExampleState();
}

class _MultiSegmentWithManualTriggersExampleState extends State<MultiSegmentWithManualTriggersExample> {
  final GlobalKey<MultiLineChartState> _chartKey = GlobalKey<MultiLineChartState>();

  @override
  Widget build(BuildContext context) {
    // Create line series with four animation phases:
    // Phase 0: Initial line (Jan-Apr) - auto-animated
    // Phase 1: First segment (Apr-May) - manual trigger
    // Phase 2: Second segment (May-Jun) - manual trigger
    // Phase 3: Final line (Jun-Aug) - manual trigger
    final series = [
      ChartSeries(
        name: 'Sales',
        dataPoints: [
          const ChartDataPoint(value: 10, label: 'Jan', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 25, label: 'Feb', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 20, label: 'Mar', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 35, label: 'Apr', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 40, label: 'May', segmentAnimationOrder: 1),
          const ChartDataPoint(value: 38, label: 'Jun', segmentAnimationOrder: 2),
          const ChartDataPoint(value: 45, label: 'Jul', segmentAnimationOrder: 3),
          const ChartDataPoint(value: 50, label: 'Aug', segmentAnimationOrder: 3),
        ],
        color: Colors.blue,
        animationConfig: const LineAnimationConfig(
          animationOrder: 0,
          animationType: LineAnimationType.drawLine,
          animationTrigger: LineAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1200),
        ),
      ),
      ChartSeries(
        name: 'Profit',
        dataPoints: [
          const ChartDataPoint(value: 5, label: 'Jan', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 12, label: 'Feb', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 18, label: 'Mar', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 22, label: 'Apr', segmentAnimationOrder: 0),
          const ChartDataPoint(value: 28, label: 'May', segmentAnimationOrder: 1),
          const ChartDataPoint(value: 30, label: 'Jun', segmentAnimationOrder: 2),
          const ChartDataPoint(value: 35, label: 'Jul', segmentAnimationOrder: 3),
          const ChartDataPoint(value: 38, label: 'Aug', segmentAnimationOrder: 3),
        ],
        color: Colors.red,
        animationConfig: const LineAnimationConfig(
          animationOrder: 0,
          animationType: LineAnimationType.fadeIn,
          animationTrigger: LineAnimationTrigger.immediate,
          duration: Duration(milliseconds: 1200),
        ),
      ),
    ];

    final style = MultiLineChartStyle(
      colors: const [Colors.blue, Colors.red],
      showLegend: true,
      segmentAnimationConfigs: {
        1: const SegmentAnimationConfig(
          segmentAnimationOrder: 1,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: LineAnimationTrigger.manual,
          duration: Duration(milliseconds: 600),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
        2: const SegmentAnimationConfig(
          segmentAnimationOrder: 2,
          animationType: SegmentAnimationType.slideUp,
          animationTrigger: LineAnimationTrigger.manual,
          duration: Duration(milliseconds: 600),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
        3: const SegmentAnimationConfig(
          segmentAnimationOrder: 3,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: LineAnimationTrigger.manual,
          duration: Duration(milliseconds: 800),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
      },
    );

    return Column(
      children: [
        const Text(
          'Multi-Segment with Progressive Triggers',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 300,
          width: 350,
          child: MultiLineChart(
            key: _chartKey,
            series: series,
            style: style,
          ),
        ),
        const SizedBox(height: 20),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _chartKey.currentState?.triggerAnimation(1);
              },
              child: const Text('Add May Data'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _chartKey.currentState?.triggerAnimation(2);
              },
              child: const Text('Add Jun Data'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _chartKey.currentState?.triggerAnimation(3);
              },
              child: const Text('Complete: Add Jul-Aug Data'),
            ),
          ],
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

    const style = StackedBarChartStyle(
      barSpacing: 0.2,
      cornerRadius: 8,
    );

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quarterly Product Sales',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Export SVG',
              icon: const Icon(Icons.image),
              onPressed: () => _exportStackedBarChartSvg(context, data, style, 'Quarterly Product Sales'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        MaterialStackedBarChart(
          data: data,
          width: 350,
          height: 300,
          style: style,
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
        // const Text(
        //   'Goal Achievement',
        //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        // ),
        // const SizedBox(height: 20),
        MaterialChartHollowSemiCircle(
          percentage: 75,
          size: 200,
          hollowRadius: 0.2,
          style: ChartStyle(
            activeColor: Colors.green,
            activeColors: const [Colors.green, Colors.yellow, Colors.red],
            activePercentages: const [30, 25, 20],
            activeLabels: const ['Completed', 'In Review', 'Blocked'],
            inactiveColor: Colors.grey,
            showLegend: true, legendSpacing: 50,
            percentagePosition: PercentagePosition.top,
            percentageOffset: 0.0,
            percentageFormatter: (value) {
              return '${value.toStringAsFixed(0)}%'; // Default formatting function, is there if we don't put anything in that parameter
            },
            // Examples of other functions we could use:
            // Simple integer percent:
            // (p) => '${p.toStringAsFixed(0)}%'
            // One decimal:
            // (p) => '${p.toStringAsFixed(1)}%'
            // Custom label:
            // (p) => 'Progress: ${p.toStringAsFixed(0)}%'
            // Show fraction + percent:
            // (p) {
            //   final total = 100.0;
            //   final done = (p / 100 * total).round();
            //   return '$done/$total (${p.toStringAsFixed(0)}%)';
            // }
            showPercentageText: true,
          ),
        ),
        // const SizedBox(height: 20),
        // const Text('75% Complete'),
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
          width: 600,
          height: 500,
          style: GanttChartStyle(),
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

// Hybrid Chart Animation Example - Demonstrates delay-based and trigger-based animations
class HybridChartAnimationExample extends StatefulWidget {
  const HybridChartAnimationExample({super.key});

  @override
  State<HybridChartAnimationExample> createState() => _HybridChartAnimationExampleState();
}

class _HybridChartAnimationExampleState extends State<HybridChartAnimationExample> {
  late List<HybridChartData> _priceData;

  @override
  void initState() {
    super.initState();
    _priceData = _buildPriceData();
  }

  /// Build sample price data for hybrid chart
  List<HybridChartData> _buildPriceData() {
    return [
      HybridChartData(label: 'Mon', open: 100, high: 115, low: 95, close: 105, volume: 10500),
      HybridChartData(label: 'Tue', open: 105, high: 120, low: 100, close: 110, volume: 11000),
      HybridChartData(label: 'Wed', open: 110, high: 125, low: 105, close: 115, volume: 11500),
      HybridChartData(label: 'Thu', open: 115, high: 118, low: 108, close: 112, volume: 11200),
      HybridChartData(label: 'Fri', open: 112, high: 122, low: 110, close: 120, volume: 12000),
      HybridChartData(label: 'Mon', open: 120, high: 128, low: 115, close: 125, volume: 12500),
      HybridChartData(label: 'Tue', open: 125, high: 130, low: 120, close: 128, volume: 12800),
      HybridChartData(label: 'Wed', open: 128, high: 135, low: 122, close: 132, volume: 13200),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ===== SECTION 1: Delay-Based Animations =====
          _buildDelayBasedSection(),
          const SizedBox(height: 40),

          // ===== SECTION 2: Alternative Animation Styles =====
          _buildAlternativeSection(),
          const SizedBox(height: 40),

          // ===== SECTION 3: Manual Trigger Animations =====
          _buildManualTriggerSection(),
          const SizedBox(height: 40),

          // ===== SECTION 4: Segment Animations =====
          _buildSegmentAnimationSection(),
          const SizedBox(height: 40),

          // ===== SECTION 5: All Manual Segment Animations =====
          _buildAllManualSegmentAnimationSection(),
        ],
      ),
    );
  }

  /// Section 1: Hybrid Chart with Delay-Based Sequential Animations
  Widget _buildDelayBasedSection() {
    // First series: animates immediately
    final series1 = HybridChartSeries(
      name: 'Price Series 1',
      dataPoints: _priceData,
      color: Colors.blue,
      lineWidth: 2.0,
      showPoints: true,
      pointSize: 6.0,
      animationConfig: const AreaAnimationConfig(
        animationOrder: 0,
        animationType: AreaAnimationType.drawLine,
        animationTrigger: AreaAnimationTrigger.afterDelay,
        duration: Duration(milliseconds: 1200),
        delayBeforeNext: Duration(milliseconds: 500),
      ),
    );

    // Second series: animates after a 500ms delay from the first
    final series2 = HybridChartSeries(
      name: 'Price Series 2',
      dataPoints: _priceData.map((p) => p.copyWithCandlestickValue(HybridCandlestickValueType.close, p.close + 5)).toList(),
      color: Colors.green,
      lineWidth: 2.0,
      showPoints: true,
      pointSize: 6.0,
      animationConfig: const AreaAnimationConfig(
        animationOrder: 1,
        animationType: AreaAnimationType.slideUp,
        animationTrigger: AreaAnimationTrigger.afterDelay,
        duration: Duration(milliseconds: 1200),
        delayBeforeNext: Duration(milliseconds: 500),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hybrid Chart - Delay-Based Sequential Animations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Multiple series animate sequentially with automatic delays between them.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 350,
            child: MaterialHybridChart(
              series: [series1, series2],
              width: 600,
              height: 350,
              style: const HybridChartStyle(
                colors: [Colors.blue, Colors.green],
                animationDuration: Duration(milliseconds: 1200),
                animationCurve: Curves.easeInOut,
                padding: EdgeInsets.fromLTRB(10, 20, 60, 20),
                showGrid: true,
                autoHorizontalGridLines: 4,
                autoVerticalGridLines: 4,
                defaultAnimationType: AreaAnimationType.drawLine,
                defaultAnimationTrigger: AreaAnimationTrigger.afterDelay,
                defaultDelayBeforeNext: Duration(milliseconds: 500),
              ),
              axisConfig: const HybridChartAxisConfig(
                priceDivisions: 5,
                dateDivisions: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Section 2: Alternative Animation Styles (Immediate and FadeIn)
  Widget _buildAlternativeSection() {
    // Series with immediate animation
    final series1 = HybridChartSeries(
      name: 'Immediate Series',
      dataPoints: _priceData,
      color: Colors.purple,
      lineWidth: 2.0,
      showPoints: true,
      pointSize: 6.0,
      animationConfig: const AreaAnimationConfig(
        animationOrder: 0,
        animationType: AreaAnimationType.fadeIn,
        animationTrigger: AreaAnimationTrigger.immediate,
        duration: Duration(milliseconds: 1000),
      ),
    );

    // Series with fade animation
    final series2 = HybridChartSeries(
      name: 'Fade Series',
      dataPoints: _priceData.map((p) => p.copyWithCandlestickValue(HybridCandlestickValueType.close, p.close + 8)).toList(),
      color: Colors.orange,
      lineWidth: 2.0,
      showPoints: true,
      pointSize: 6.0,
      animationConfig: const AreaAnimationConfig(
        animationOrder: 0,
        animationType: AreaAnimationType.fadeIn,
        animationTrigger: AreaAnimationTrigger.immediate,
        duration: Duration(milliseconds: 1000),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hybrid Chart - Simultaneous Animations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Multiple series animate simultaneously using FadeIn animation.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 350,
            child: MaterialHybridChart(
              series: [series1, series2],
              width: 600,
              height: 350,
              style: const HybridChartStyle(
                colors: [Colors.purple, Colors.orange],
                animationDuration: Duration(milliseconds: 1000),
                animationCurve: Curves.easeIn,
                padding: EdgeInsets.fromLTRB(10, 20, 60, 20),
                showGrid: true,
                autoHorizontalGridLines: 4,
                autoVerticalGridLines: 4,
                defaultAnimationType: AreaAnimationType.fadeIn,
                defaultAnimationTrigger: AreaAnimationTrigger.immediate,
              ),
              axisConfig: const HybridChartAxisConfig(
                priceDivisions: 5,
                dateDivisions: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Section 3: Hybrid Chart with Manual Trigger Animations
  Widget _buildManualTriggerSection() {
    return _ManualTriggerHybridChartWidget(priceData: _priceData);
  }

  /// Section 4: Hybrid Chart with Segment Animations
  Widget _buildSegmentAnimationSection() {
    return _SegmentAnimationHybridChartWidget(priceData: _priceData);
  }

  /// Section 5: Hybrid Chart with All Manual Segment Animations
  Widget _buildAllManualSegmentAnimationSection() {
    return _AllManualSegmentAnimationHybridChartWidget(priceData: _priceData);
  }
}

// Manual Trigger Hybrid Chart Widget
class _ManualTriggerHybridChartWidget extends StatefulWidget {
  final List<HybridChartData> priceData;

  const _ManualTriggerHybridChartWidget({required this.priceData});

  @override
  State<_ManualTriggerHybridChartWidget> createState() => _ManualTriggerHybridChartWidgetState();
}

class _ManualTriggerHybridChartWidgetState extends State<_ManualTriggerHybridChartWidget> {
  late GlobalKey<State> _chartKey;

  @override
  void initState() {
    super.initState();
    _chartKey = GlobalKey<State>();
  }

  @override
  Widget build(BuildContext context) {
    // Series with manual trigger
    final series1 = HybridChartSeries(
      name: 'Manual Trigger Series 1',
      dataPoints: widget.priceData,
      color: Colors.amber,
      lineWidth: 2.0,
      showPoints: true,
      pointSize: 6.0,
      animationConfig: const AreaAnimationConfig(
        animationOrder: 0,
        animationType: AreaAnimationType.drawLine,
        animationTrigger: AreaAnimationTrigger.manual,
        duration: Duration(milliseconds: 1000),
      ),
    );

    // Second series with manual trigger
    final series2 = HybridChartSeries(
      name: 'Manual Trigger Series 2',
      dataPoints: widget.priceData.map((p) => p.copyWithCandlestickValue(HybridCandlestickValueType.close, p.close + 10)).toList(),
      color: Colors.cyan,
      lineWidth: 2.0,
      showPoints: true,
      pointSize: 6.0,
      animationConfig: const AreaAnimationConfig(
        animationOrder: 1,
        animationType: AreaAnimationType.slideUp,
        animationTrigger: AreaAnimationTrigger.manual,
        duration: Duration(milliseconds: 1000),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hybrid Chart - Manual Trigger Animations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Use buttons to manually trigger animations for each series or all at once.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        // Control buttons in a responsive grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).triggerAnimation(0);
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Animate Series 1'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).triggerAnimation(1);
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Animate Series 2'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                foregroundColor: Colors.black87,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).triggerAnimation(0);
                  (state as dynamic).triggerAnimation(1);
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Animate All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _chartKey = GlobalKey<State>();
                });
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 350,
            child: MaterialHybridChart(
              key: _chartKey,
              series: [series1, series2],
              width: 600,
              height: 350,
              style: const HybridChartStyle(
                colors: [Colors.amber, Colors.cyan],
                animationDuration: Duration(milliseconds: 1000),
                animationCurve: Curves.easeInOut,
                padding: EdgeInsets.fromLTRB(10, 20, 60, 20),
                showGrid: true,
                autoHorizontalGridLines: 4,
                autoVerticalGridLines: 4,
                defaultAnimationTrigger: AreaAnimationTrigger.manual,
              ),
              axisConfig: const HybridChartAxisConfig(
                priceDivisions: 5,
                dateDivisions: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Segment Animation Hybrid Chart Widget
class _SegmentAnimationHybridChartWidget extends StatefulWidget {
  final List<HybridChartData> priceData;

  const _SegmentAnimationHybridChartWidget({required this.priceData});

  @override
  State<_SegmentAnimationHybridChartWidget> createState() => _SegmentAnimationHybridChartWidgetState();
}

class _SegmentAnimationHybridChartWidgetState extends State<_SegmentAnimationHybridChartWidget> {
  late GlobalKey<State> _chartKey;

  @override
  void initState() {
    super.initState();
    _chartKey = GlobalKey<State>();
  }

  @override
  Widget build(BuildContext context) {
    // Series with segment animations:
    // Segment 0: Initial data points (Mon-Thu) - auto-animated
    // Segment 1: First transition (Fri) - manual trigger
    // Segment 2: Second transition (Mon) - manual trigger
    // Segment 3: Final segment (Tue-Wed) - manual trigger
    final series = HybridChartSeries(
      name: 'Progressive Price Movement',
      dataPoints: [
        HybridChartData(label: 'Mon', open: 100, high: 115, low: 95, close: 105, volume: 10500, segmentAnimationOrder: 0),
        HybridChartData(label: 'Tue', open: 105, high: 120, low: 100, close: 110, volume: 11000, segmentAnimationOrder: 0),
        HybridChartData(label: 'Wed', open: 110, high: 125, low: 105, close: 115, volume: 11500, segmentAnimationOrder: 0),
        HybridChartData(label: 'Thu', open: 115, high: 118, low: 108, close: 112, volume: 11200, segmentAnimationOrder: 0),
        HybridChartData(label: 'Fri', open: 112, high: 122, low: 110, close: 120, volume: 12000, segmentAnimationOrder: 1),
        HybridChartData(label: 'Mon', open: 120, high: 128, low: 115, close: 125, volume: 12500, segmentAnimationOrder: 2),
        HybridChartData(label: 'Tue', open: 125, high: 130, low: 120, close: 128, volume: 12800, segmentAnimationOrder: 3),
        HybridChartData(label: 'Wed', open: 128, high: 135, low: 122, close: 132, volume: 13200, segmentAnimationOrder: 3),
      ],
      color: Colors.blue,
      lineWidth: 2.0,
      showPoints: true,
      pointSize: 6.0,
      animationConfig: const AreaAnimationConfig(
        animationOrder: 0,
        animationType: AreaAnimationType.drawLine,
        animationTrigger: AreaAnimationTrigger.immediate,
        duration: Duration(milliseconds: 1200),
      ),
    );

    final style = HybridChartStyle(
      colors: const [Colors.blue],
      animationDuration: Duration(milliseconds: 1200),
      animationCurve: Curves.easeInOut,
      padding: const EdgeInsets.fromLTRB(10, 20, 60, 20),
      showGrid: true,
      autoHorizontalGridLines: 4,
      autoVerticalGridLines: 4,
      defaultAnimationType: AreaAnimationType.drawLine,
      segmentAnimationConfigs: {
        1: const SegmentAnimationConfig(
          segmentAnimationOrder: 1,
          animationType: SegmentAnimationType.drawPoint,
          duration: Duration(milliseconds: 600),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
        2: const SegmentAnimationConfig(
          segmentAnimationOrder: 2,
          animationType: SegmentAnimationType.slideUp,
          duration: Duration(milliseconds: 600),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
        3: const SegmentAnimationConfig(
          segmentAnimationOrder: 3,
          animationType: SegmentAnimationType.drawPoint,
          duration: Duration(milliseconds: 800),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hybrid Chart - Segment Animations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Initial segment animates automatically, then trigger additional segments progressively.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        // Control buttons
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _chartKey = GlobalKey<State>();
            });
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade100,
            foregroundColor: Colors.red.shade900,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 350,
            child: MaterialHybridChart(
              key: _chartKey,
              series: [series],
              width: 600,
              height: 350,
              style: style,
              axisConfig: const HybridChartAxisConfig(
                priceDivisions: 5,
                dateDivisions: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// All Manual Segment Animation Hybrid Chart Widget
class _AllManualSegmentAnimationHybridChartWidget extends StatefulWidget {
  final List<HybridChartData> priceData;

  const _AllManualSegmentAnimationHybridChartWidget({required this.priceData});

  @override
  State<_AllManualSegmentAnimationHybridChartWidget> createState() => _AllManualSegmentAnimationHybridChartWidgetState();
}

class _AllManualSegmentAnimationHybridChartWidgetState extends State<_AllManualSegmentAnimationHybridChartWidget> {
  late GlobalKey<State> _chartKey;

  @override
  void initState() {
    super.initState();
    _chartKey = GlobalKey<State>();
  }

  @override
  Widget build(BuildContext context) {
    // Series with ALL segment animations using manual triggers:
    // Segment 0: Manual trigger (Mon-Thu)
    // Segment 1: Manual trigger (Fri)
    // Segment 2: Manual trigger (Mon)
    // Segment 3: Manual trigger (Tue-Wed)
    final series = HybridChartSeries(
      name: 'Manual Segment Animation',
      dataPoints: [
        HybridChartData(label: 'Mon', open: 100, high: 115, low: 95, close: 105, volume: 10500, segmentAnimationOrder: 0),
        HybridChartData(label: 'Tue', open: 105, high: 120, low: 100, close: 110, volume: 11000, segmentAnimationOrder: 0),
        HybridChartData(label: 'Wed', open: 110, high: 125, low: 105, close: 115, volume: 11500, segmentAnimationOrder: 0),
        HybridChartData(label: 'Thu', open: 115, high: 118, low: 108, close: 112, volume: 11200, segmentAnimationOrder: 0),
        HybridChartData(label: 'Fri', open: 112, high: 122, low: 110, close: 120, volume: 12000, segmentAnimationOrder: 1),
        HybridChartData(label: 'Mon', open: 120, high: 128, low: 115, close: 125, volume: 12500, segmentAnimationOrder: 2),
        HybridChartData(label: 'Tue', open: 125, high: 130, low: 120, close: 128, volume: 12800, segmentAnimationOrder: 3),
        HybridChartData(label: 'Wed', open: 128, high: 135, low: 122, close: 132, volume: 13200, segmentAnimationOrder: 3),
      ],
      color: Colors.blue,
      lineWidth: 2.0,
      showPoints: true,
      pointSize: 6.0,
      animationConfig: const AreaAnimationConfig(
        animationOrder: 0,
        animationType: AreaAnimationType.drawLine,
        animationTrigger: AreaAnimationTrigger.manual,
        duration: Duration(milliseconds: 1200),
      ),
    );

    final style = HybridChartStyle(
      colors: const [Colors.blue],
      animationDuration: Duration(milliseconds: 1200),
      animationCurve: Curves.easeInOut,
      padding: const EdgeInsets.fromLTRB(10, 20, 60, 20),
      showGrid: true,
      autoHorizontalGridLines: 4,
      autoVerticalGridLines: 4,
      defaultAnimationType: AreaAnimationType.drawLine,
      defaultAnimationTrigger: AreaAnimationTrigger.manual,
      segmentAnimationConfigs: {
        0: const SegmentAnimationConfig(
          segmentAnimationOrder: 0,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: AreaAnimationTrigger.manual,
          duration: Duration(milliseconds: 600),
        ),
        1: const SegmentAnimationConfig(
          segmentAnimationOrder: 1,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: AreaAnimationTrigger.manual,
          duration: Duration(milliseconds: 600),
        ),
        2: const SegmentAnimationConfig(
          segmentAnimationOrder: 2,
          animationType: SegmentAnimationType.slideUp,
          animationTrigger: AreaAnimationTrigger.manual,
          duration: Duration(milliseconds: 600),
        ),
        3: const SegmentAnimationConfig(
          segmentAnimationOrder: 3,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: AreaAnimationTrigger.manual,
          duration: Duration(milliseconds: 800),
        ),
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hybrid Chart - All Manual Segment Animations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'All segments wait for your button input - nothing animates automatically.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        // Control buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Segment 0 controls
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).triggerAnimation(0);
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Segment 0'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).reverseAnimation(0);
                }
              },
              icon: const Icon(Icons.fast_rewind),
              label: const Text('Reverse Seg 0'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade300,
                foregroundColor: Colors.white,
              ),
            ),

            // Segment 1 controls
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).triggerAnimation(1);
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Segment 1'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).reverseAnimation(1);
                }
              },
              icon: const Icon(Icons.fast_rewind),
              label: const Text('Reverse Seg 1'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade300,
                foregroundColor: Colors.white,
              ),
            ),

            // Segment 2 controls
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).triggerAnimation(2);
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Segment 2'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).reverseAnimation(2);
                }
              },
              icon: const Icon(Icons.fast_rewind),
              label: const Text('Reverse Seg 2'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade300,
                foregroundColor: Colors.white,
              ),
            ),

            // Segment 3 controls
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).triggerAnimation(3);
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Segment 3'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final state = _chartKey.currentState;
                if (state != null) {
                  (state as dynamic).reverseAnimation(3);
                }
              },
              icon: const Icon(Icons.fast_rewind),
              label: const Text('Reverse Seg 3'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade300,
                foregroundColor: Colors.white,
              ),
            ),

            // Reset all
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _chartKey = GlobalKey<State>();
                });
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 350,
            child: MaterialHybridChart(
              key: _chartKey,
              series: [series],
              width: 600,
              height: 350,
              style: style,
              axisConfig: const HybridChartAxisConfig(
                priceDivisions: 5,
                dateDivisions: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Hybrid Chart Mixed Animation Example
class HybridChartMixedAnimationsExample extends StatefulWidget {
  const HybridChartMixedAnimationsExample({super.key});

  @override
  State<HybridChartMixedAnimationsExample> createState() => _HybridChartMixedAnimationsExampleState();
}

class _HybridChartMixedAnimationsExampleState extends State<HybridChartMixedAnimationsExample> {
  late GlobalKey<State> _chartKey;

  @override
  void initState() {
    super.initState();
    _chartKey = GlobalKey<State>();
  }

  void _triggerOrder(int order) {
    final state = _chartKey.currentState;
    if (state != null) {
      (state as dynamic).triggerAnimation(order);
    }
  }

  void _reverseOrder(int order) {
    final state = _chartKey.currentState;
    if (state != null) {
      (state as dynamic).reverseAnimation(order);
    }
  }

  List<HybridChartData> _buildSeriesData(double offset) {
    return [
      HybridChartData(label: 'Mon', open: 98 + offset, high: 108 + offset, low: 95 + offset, close: 102 + offset, segmentAnimationOrder: 0),
      HybridChartData(label: 'Tue', open: 102 + offset, high: 112 + offset, low: 100 + offset, close: 108 + offset, segmentAnimationOrder: 0),
      HybridChartData(label: 'Wed', open: 108 + offset, high: 118 + offset, low: 106 + offset, close: 114 + offset, segmentAnimationOrder: 1),
      HybridChartData(label: 'Thu', open: 114 + offset, high: 120 + offset, low: 110 + offset, close: 116 + offset, segmentAnimationOrder: 1),
      HybridChartData(label: 'Fri', open: 116 + offset, high: 126 + offset, low: 114 + offset, close: 123 + offset, segmentAnimationOrder: 2),
      HybridChartData(label: 'Sat', open: 123 + offset, high: 128 + offset, low: 119 + offset, close: 121 + offset, segmentAnimationOrder: 2),
      HybridChartData(label: 'Sun', open: 121 + offset, high: 130 + offset, low: 118 + offset, close: 127 + offset, segmentAnimationOrder: 3),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final baselineSeries = HybridChartSeries(
      name: 'Baseline (Auto Line)',
      dataPoints: _buildSeriesData(0),
      color: Colors.indigo,
      lineWidth: 2.2,
      showPoints: true,
      pointSize: 5,
      animationConfig: const AreaAnimationConfig(
        animationOrder: 0,
        animationType: AreaAnimationType.drawLine,
        animationTrigger: AreaAnimationTrigger.afterDelay,
        duration: Duration(milliseconds: 1000),
        delayBeforeNext: Duration(milliseconds: 350),
      ),
    );

    final signalSeries = HybridChartSeries(
      name: 'Signal (Manual Line)',
      dataPoints: _buildSeriesData(4),
      color: Colors.teal,
      lineWidth: 2.2,
      showPoints: true,
      pointSize: 5,
      animationConfig: const AreaAnimationConfig(
        animationOrder: 10,
        animationType: AreaAnimationType.slideUp,
        animationTrigger: AreaAnimationTrigger.manual,
        duration: Duration(milliseconds: 950),
      ),
    );

    final style = HybridChartStyle(
      colors: const [Colors.indigo, Colors.teal],
      animationCurve: Curves.easeInOut,
      animationDuration: const Duration(milliseconds: 1100),
      defaultAnimationType: AreaAnimationType.drawLine,
      defaultAnimationTrigger: AreaAnimationTrigger.afterDelay,
      defaultDelayBeforeNext: const Duration(milliseconds: 350),
      showGrid: true,
      autoHorizontalGridLines: 4,
      autoVerticalGridLines: 6,
      padding: const EdgeInsets.fromLTRB(10, 20, 60, 20),
      segmentAnimationConfigs: {
        1: const SegmentAnimationConfig(
          segmentAnimationOrder: 1,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: AreaAnimationTrigger.afterDelay,
          duration: Duration(milliseconds: 650),
          delayBeforeNext: Duration(milliseconds: 150),
        ),
        2: const SegmentAnimationConfig(
          segmentAnimationOrder: 2,
          animationType: SegmentAnimationType.slideUp,
          animationTrigger: AreaAnimationTrigger.manual,
          duration: Duration(milliseconds: 700),
        ),
        3: const SegmentAnimationConfig(
          segmentAnimationOrder: 3,
          animationType: SegmentAnimationType.drawPoint,
          animationTrigger: AreaAnimationTrigger.manual,
          duration: Duration(milliseconds: 850),
        ),
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hybrid Chart - Mixed Line + Segment Animations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Line 1 and early segments animate automatically. Trigger the second line and later segments with buttons.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _triggerOrder(10),
              icon: const Icon(Icons.show_chart),
              label: const Text('Play Manual Line'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _reverseOrder(10),
              icon: const Icon(Icons.undo),
              label: const Text('Reverse Manual Line'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade300,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _triggerOrder(2),
              icon: const Icon(Icons.timeline),
              label: const Text('Play Segment 2'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _triggerOrder(3),
              icon: const Icon(Icons.timeline),
              label: const Text('Play Segment 3'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _triggerOrder(10);
                _triggerOrder(2);
                _triggerOrder(3);
              },
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('Play All Manual'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _chartKey = GlobalKey<State>();
                });
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Demo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 360,
            child: MaterialHybridChart(
              key: _chartKey,
              series: [baselineSeries, signalSeries],
              width: 620,
              height: 360,
              style: style,
              axisConfig: const HybridChartAxisConfig(
                priceDivisions: 5,
                dateDivisions: 6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Hybrid Chart Example
class HybridChartExample extends StatefulWidget {
  const HybridChartExample({super.key});

  @override
  State<HybridChartExample> createState() => _HybridChartExampleState();
}

class _HybridChartExampleState extends State<HybridChartExample> {
  HybridChartType _chartType = HybridChartType.area;
  double _chartWidth = 800;
  double _chartHeight = 400;
  bool _showChartTypeToggle = true;
  late List<HybridChartData> _hybridData;

  bool _showPoints = true;
  double _pointSize = 6.0;
  bool _showVolume = true;
  bool _showVolumeBelow = true;
  double _volumeBarHeightRatio = 0.25;
  double _volumeAreaHeightRatio = 0.15;
  double _volumeBarVerticalOffset = 20;
  double _volumeBarWidth = 10;
  double _volumeBarOpacity = 0.6;
  bool _showVolumeTooltip = true;

  bool _showGrid = false;
  int _autoHorizontalGridLines = 3;
  int _autoVerticalGridLines = 3;

  double _candleWidth = 10.0;
  double _wickWidth = 2.0;
  bool _forceYAxisFromZero = true;
  bool _singleCrosshair = false;

  bool _showVerticalLinesAtEveryLabels = false;
  double _defaultLineWidth = 2.0;
  double _keyEventMarkerVerticalOffset = 18.0;
  double _keyEventMarkerMinHoverRadius = 15.0;
  double _keyEventMarkerSize = 10.0;
  double _volumeTooltipBorderRadiusState = 6.0;
  double _volumeTooltipOpacityState = 0.9;
  bool _showKeyEventMarkersState = true;
  double _animationDurationMs = 1500;
  bool _showPointTooltipOnHover = true;
  bool _showDragTooltip = true;

  double _areaTopOpacity = 0.5;
  double _areaBottomOpacity = 0.0;

  int _xSpanSlots = 35;

  EdgeInsets _padding = const EdgeInsets.fromLTRB(10, 40, 60, 10);
  double _yAxisTitleGap = 10.0;
  double _xAxisTitleGap = 25.0;
  double _xAxisLabelGap = 8.0;
  double _yAxisLabelGap = 8.0;
  YAxisPosition _yAxisPosition = YAxisPosition.right;
  XAxisPosition _xAxisPosition = XAxisPosition.top;
  double _yAxisOpacity = 0.50;
  double _xAxisOpacity = 0.50;
  double _xAxisStrokeWidth = 3.00;
  double _yAxisStrokeWidth = 3.00;
  double _yAxisMaxOffset = 50.0;
  double _gridStrokeWidth = 0.5;
  double _gridOpacity = 1.0;

  final GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _hybridData = _buildHybridData();
  }

  List<HybridChartData> _buildHybridData() {
    return [
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
  }

  void _updateHybridPointField(int pointIndex, HybridCandlestickValueType valueType, double newValue) {
    setState(() {
      final updated = List<HybridChartData>.from(_hybridData);
      final old = updated[pointIndex];
      updated[pointIndex] = old.copyWithCandlestickValue(valueType, newValue);
      _hybridData = updated;
    });
  }

  Future<void> _exportHybridSvg(
    BuildContext context,
    HybridChartStyle style,
    HybridChartAxisConfig axisConfig,
    List<HybridChartSeries> series,
    String title,
  ) async {
    if (_chartType == HybridChartType.candlestick) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SVG export currently supports area/line modes only.')),
      );
      return;
    }

    try {
      final exporter = HybridChartSvgExporter();
      final svg = exporter.exportSvg(
        size: Size(_chartWidth, _chartHeight),
        series: series,
        style: style,
        axisConfig: axisConfig,
        chartType: _chartType,
        options: HybridChartSvgOptions(
          includeAxes: true,
          includeAxisLabels: true,
          includeGrid: true,
          includeTitle: true,
          includeLegend: true,
          includeVolume: true,
          includeKeyEvents: true,
          title: title,
        ),
      );

      final file = await _saveSvgToDocuments(svg, fileName: 'hybrid_chart_${DateTime.now().millisecondsSinceEpoch}.svg');
      if (!context.mounted) return;

      await _showSvgPreviewDialog(context, svg, file);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SVG export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hybridData = _hybridData;

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
        color: const ui.Color.fromARGB(255, 189, 149, 27),
      ),
    ];
    const chartTitle = 'Hybrid Chart (Area + Candlestick + MultiLine)';
    final axisConfig = HybridChartAxisConfig(
      yAxisWidth: 0.0,
      xAxisHeight: 0.0,
      yAxisPosition: _yAxisPosition,
      xAxisPosition: _xAxisPosition,
    );
    final style = HybridChartStyle.unified(
      xAxisTitle: 'Date',
      yAxisTitle: 'Price (USD)',
      xAxisTitleStyle: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
      yAxisTitleStyle: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w600),
      tooltipStyle: TooltipStyleConfig(borderWidth: 10),
      padding: _padding,
      chartAreaBackgroundColor: Colors.white,
      keyEventMarkerConfig: KeyEventMarkerConfig(
        verticalOffset: _keyEventMarkerVerticalOffset,
        defaultColor: Colors.red,
        minHoverRadius: _keyEventMarkerMinHoverRadius,
        size: _keyEventMarkerSize,
      ),
      showVolumeTooltip: _showVolumeTooltip,
      showVolume: _showVolume,
      volumeTooltipBackgroundColor: Colors.black,
      volumeTooltipTextColor: Colors.white,
      volumeTooltipOpacity: _volumeTooltipOpacityState,
      volumeTooltipBorderRadius: _volumeTooltipBorderRadiusState,
      volumeBarColor: Colors.grey,
      volumeBarOpacity: _volumeBarOpacity,
      volumeBarWidth: _volumeBarWidth,
      volumeBarHeightRatio: _volumeBarHeightRatio,
      volumeAreaHeightRatio: _volumeAreaHeightRatio,
      showVolumeBelowChart: _showVolumeBelow,
      volumeBarVerticalOffset: _volumeBarVerticalOffset,
      showGrid: _showGrid,
      showPoints: _showPoints,
      defaultLineWidth: _defaultLineWidth,
      spacing: 0.2,
      verticalLineColor: Colors.purple,
      verticalLineWidth: 0,
      candleWidth: _candleWidth,
      wickWidth: _wickWidth,
      defaultPointSize: _pointSize,
      forceYAxisFromZero: _forceYAxisFromZero,
      colors: [Colors.blue, Colors.green, Colors.red],
      showKeyEventMarkers: _showKeyEventMarkersState,
      bullishColor: Colors.green,
      bearishColor: Colors.red,
      areaFillOpacityTop: _areaTopOpacity,
      areaFillOpacityBottom: _areaBottomOpacity,
      yAxisMaxOffset: _yAxisMaxOffset,
      xAxisTitleGap: _xAxisTitleGap,
      yAxisTitleGap: _yAxisTitleGap,
      xAxisLabelGap: _xAxisLabelGap,
      yAxisLabelGap: _yAxisLabelGap,
      xSpanSlots: _xSpanSlots,
      gridColor: Colors.grey,
      gridStrokeWidth: _gridStrokeWidth,
      gridOpacity: _gridOpacity,
      showVerticalLinesAtEveryLabels: _showVerticalLinesAtEveryLabels,
      yAxisColor: Colors.black,
      xAxisColor: Colors.black,
      yAxisOpacity: _yAxisOpacity,
      xAxisOpacity: _xAxisOpacity,
      xAxisStrokeWidth: _xAxisStrokeWidth,
      yAxisStrokeWidth: _yAxisStrokeWidth,
      autoHorizontalGridLines: _autoHorizontalGridLines,
      autoVerticalGridLines: _autoVerticalGridLines,
      animationDuration: Duration(milliseconds: _animationDurationMs.toInt()),
      singleCrosshair: _singleCrosshair,
      singleCrosshairOrientation: SingleCrosshairOrientation.vertical,
      crosshair: AreaCrosshairConfig(
        lineColor: Colors.grey,
        lineWidth: 1,
        showLabel: true,
        enabled: true,
      ),
      baseline: BaselineConfig(
        show: true,
        strokeWidth: 1.5,
        dashPattern: [5.0, 3.0],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExportHeader(
          context,
          chartTitle,
          _chartKey,
          onExportSvg: () => _exportHybridSvg(context, style, axisConfig, hybridSeries, chartTitle),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: _chartWidth,
          height: _chartHeight,
          child: RepaintBoundary(
            key: _chartKey,
            child: MaterialHybridChart(
              showChartTypeToggle: _showChartTypeToggle,
              series: hybridSeries,
              width: _chartWidth,
              height: _chartHeight,
              initialChartType: _chartType,
              enablePointDrag: true,
              enableHoverPointScale: true,
              showPointTooltipOnHover: _showPointTooltipOnHover,
              showDragTooltip: _showDragTooltip,
              onPointValueChange: (seriesIndex, pointIndex, newValue) {
                if (seriesIndex != 0) return;
                if (pointIndex < 0 || pointIndex >= _hybridData.length) return;
                _updateHybridPointField(pointIndex, HybridCandlestickValueType.close, newValue);
              },
              onCandlestickValueChange: (seriesIndex, pointIndex, valueType, newValue) {
                if (seriesIndex != 0) return;
                if (pointIndex < 0 || pointIndex >= _hybridData.length) return;
                _updateHybridPointField(pointIndex, valueType, newValue);
              },
              axisConfig: axisConfig,
              style: style,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 16, runSpacing: 8, children: [
                  const Text('For debugging: '),
                  Row(children: [
                    const Text('Show Points'),
                    Switch(value: _showPoints, onChanged: (v) => setState(() => _showPoints = v)),
                  ]),
                  _buildSlider('Point Size', _pointSize, 1, 12, (v) => setState(() => _pointSize = v)),
                  Row(children: [
                    const Text('Show Point Tooltip On Hover'),
                    Switch(value: _showPointTooltipOnHover, onChanged: (v) => setState(() => _showPointTooltipOnHover = v)),
                  ]),
                  Row(children: [
                    const Text('Show Drag Tooltip'),
                    Switch(value: _showDragTooltip, onChanged: (v) => setState(() => _showDragTooltip = v)),
                  ]),
                  Row(children: [
                    const Text('Show Volume'),
                    Switch(value: _showVolume, onChanged: (v) => setState(() => _showVolume = v)),
                  ]),
                  Row(children: [
                    const Text('Show Volume Below'),
                    Switch(value: _showVolumeBelow, onChanged: (v) => setState(() => _showVolumeBelow = v)),
                  ]),
                  Row(children: [
                    const Text('Force Y Axis From Zero'),
                    Switch(value: _forceYAxisFromZero, onChanged: (v) => setState(() => _forceYAxisFromZero = v)),
                  ]),
                  Row(children: [
                    const Text('Show Chart Type Toggle'),
                    Switch(value: _showChartTypeToggle, onChanged: (v) => setState(() => _showChartTypeToggle = v)),
                  ]),
                  Row(children: [
                    const Text('Show Volume Tooltip'),
                    Switch(value: _showVolumeTooltip, onChanged: (v) => setState(() => _showVolumeTooltip = v)),
                  ]),
                  _buildSlider('Chart Width', _chartWidth, 300, 1200, (v) => setState(() => _chartWidth = v)),
                  _buildSlider('Chart Height', _chartHeight, 200, 900, (v) => setState(() => _chartHeight = v)),
                  Row(children: [
                    const Text('Show Grid'),
                    Switch(value: _showGrid, onChanged: (v) => setState(() => _showGrid = v)),
                  ]),
                  _buildSlider('Grid Stroke Width', _gridStrokeWidth, 0.0, 10.0, (v) => setState(() => _gridStrokeWidth = v)),
                  _buildSlider('Grid Opacity', _gridOpacity, 0.0, 1.0, (v) => setState(() => _gridOpacity = v)),
                  _buildSlider('Auto Horizontal Grid Lines', _autoHorizontalGridLines.toDouble(), 0, 20, (v) => setState(() => _autoHorizontalGridLines = v.toInt())),
                  _buildSlider('Auto Vertical Grid Lines', _autoVerticalGridLines.toDouble(), 0, 20, (v) => setState(() => _autoVerticalGridLines = v.toInt())),
                  Row(children: [
                    const Text('Show Vertical Lines At Labels'),
                    Switch(value: _showVerticalLinesAtEveryLabels, onChanged: (v) => setState(() => _showVerticalLinesAtEveryLabels = v)),
                  ]),
                  Row(children: [
                    const Text('Single Crosshair'),
                    Switch(value: _singleCrosshair, onChanged: (v) => setState(() => _singleCrosshair = v)),
                  ]),
                ]),
                const SizedBox(height: 8),
                _buildSlider('Candle Width', _candleWidth, 1, 80, (v) => setState(() => _candleWidth = v)),
                _buildSlider('Wick Width', _wickWidth, 0.5, 10, (v) => setState(() => _wickWidth = v)),
                _buildSlider('Volume Bar Height Ratio', _volumeBarHeightRatio, 0.0, 1.0, (v) => setState(() => _volumeBarHeightRatio = v)),
                _buildSlider('Volume Area Height Ratio', _volumeAreaHeightRatio, 0.0, 0.5, (v) => setState(() => _volumeAreaHeightRatio = v)),
                _buildSlider('Volume Vertical Offset', _volumeBarVerticalOffset, -50, 200, (v) => setState(() => _volumeBarVerticalOffset = v)),
                _buildSlider('Volume Bar Width', _volumeBarWidth, 1, 80, (v) => setState(() => _volumeBarWidth = v)),
                _buildSlider('Volume Opacity', _volumeBarOpacity, 0.0, 1.0, (v) => setState(() => _volumeBarOpacity = v)),
                _buildSlider('Volume Tooltip Border Radius', _volumeTooltipBorderRadiusState, 0, 40, (v) => setState(() => _volumeTooltipBorderRadiusState = v)),
                _buildSlider('Volume Tooltip Opacity', _volumeTooltipOpacityState, 0.0, 1.0, (v) => setState(() => _volumeTooltipOpacityState = v)),
                _buildSlider('Default Line Width', _defaultLineWidth, 0.0, 10.0, (v) => setState(() => _defaultLineWidth = v)),
                _buildSlider('Area Top Opacity', _areaTopOpacity, 0.0, 1.0, (v) => setState(() => _areaTopOpacity = v)),
                _buildSlider('Area Bottom Opacity', _areaBottomOpacity, 0.0, 1.0, (v) => setState(() => _areaBottomOpacity = v)),
                Row(children: [
                  const Text('Show Key Event Markers'),
                  Switch(value: _showKeyEventMarkersState, onChanged: (v) => setState(() => _showKeyEventMarkersState = v)),
                ]),
                _buildSlider('Key Event Marker Vertical Offset', _keyEventMarkerVerticalOffset, -50, 200, (v) => setState(() => _keyEventMarkerVerticalOffset = v)),
                _buildSlider('Key Event Marker Min Hover Radius', _keyEventMarkerMinHoverRadius, 0, 50, (v) => setState(() => _keyEventMarkerMinHoverRadius = v)),
                _buildSlider('Key Event Marker Size', _keyEventMarkerSize, 2, 40, (v) => setState(() => _keyEventMarkerSize = v)),
                _buildSlider('xSpanSlots', _xSpanSlots.toDouble(), 5, 120, (v) => setState(() => _xSpanSlots = v.toInt())),
                const SizedBox(height: 8),
                const Text('Padding (L, T, R, B):'),
                _buildSlider('Padding Left', _padding.left, 0, 120, (v) => setState(() => _padding = EdgeInsets.fromLTRB(v, _padding.top, _padding.right, _padding.bottom))),
                _buildSlider('Padding Top', _padding.top, 0, 120, (v) => setState(() => _padding = EdgeInsets.fromLTRB(_padding.left, v, _padding.right, _padding.bottom))),
                _buildSlider('Padding Right', _padding.right, 0, 120, (v) => setState(() => _padding = EdgeInsets.fromLTRB(_padding.left, _padding.top, v, _padding.bottom))),
                _buildSlider('Padding Bottom', _padding.bottom, 0, 120, (v) => setState(() => _padding = EdgeInsets.fromLTRB(_padding.left, _padding.top, _padding.right, v))),
                const SizedBox(height: 8),
                const Text('Axis & Grid Styling'),
                Row(children: [
                  const Text('Y Axis Position'),
                  const SizedBox(width: 8),
                  DropdownButton<YAxisPosition>(
                    value: _yAxisPosition,
                    items: YAxisPosition.values.map((p) => DropdownMenuItem(value: p, child: Text(p == YAxisPosition.left ? 'Left' : 'Right'))).toList(),
                    onChanged: (v) => setState(() => _yAxisPosition = v ?? YAxisPosition.right),
                  ),
                  const SizedBox(width: 24),
                  const Text('X Axis Position'),
                  const SizedBox(width: 8),
                  DropdownButton<XAxisPosition>(
                    value: _xAxisPosition,
                    items: XAxisPosition.values.map((p) => DropdownMenuItem(value: p, child: Text(p == XAxisPosition.top ? 'Top' : 'Bottom'))).toList(),
                    onChanged: (v) => setState(() => _xAxisPosition = v ?? XAxisPosition.top),
                  ),
                ]),
                _buildSlider('Y Axis Title Gap', _yAxisTitleGap, 0, 80, (v) => setState(() => _yAxisTitleGap = v)),
                _buildSlider('X Axis Title Gap', _xAxisTitleGap, 0, 80, (v) => setState(() => _xAxisTitleGap = v)),
                _buildSlider('Y Axis Label Gap', _yAxisLabelGap, 0, 80, (v) => setState(() => _yAxisLabelGap = v)),
                _buildSlider('X Axis Label Gap', _xAxisLabelGap, 0, 80, (v) => setState(() => _xAxisLabelGap = v)),
                _buildSlider('Y Axis Opacity', _yAxisOpacity, 0.0, 1.0, (v) => setState(() => _yAxisOpacity = v)),
                _buildSlider('X Axis Opacity', _xAxisOpacity, 0.0, 1.0, (v) => setState(() => _xAxisOpacity = v)),
                _buildSlider('X Axis Stroke Width', _xAxisStrokeWidth, 0.0, 10.0, (v) => setState(() => _xAxisStrokeWidth = v)),
                _buildSlider('Y Axis Stroke Width', _yAxisStrokeWidth, 0.0, 10.0, (v) => setState(() => _yAxisStrokeWidth = v)),
                _buildSlider('Y Axis Max Offset', _yAxisMaxOffset, 0, 200, (v) => setState(() => _yAxisMaxOffset = v)),
                const SizedBox(height: 8),
                _buildSlider('Animation Duration (ms)', _animationDurationMs, 0, 5000, (v) => setState(() => _animationDurationMs = v)),
                const SizedBox(height: 12),
                Row(children: [
                  ElevatedButton(onPressed: _resetDefaults, child: const Text('Reset Defaults')),
                  const SizedBox(width: 12),
                  ElevatedButton(onPressed: () => setState(() {}), child: const Text('Refresh')),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value is double ? value.toStringAsFixed(2) : value.toString())]),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ]),
    );
  }

  void _resetDefaults() {
    setState(() {
      _chartType = HybridChartType.candlestick;
      _chartWidth = 800;
      _chartHeight = 400;

      _showPoints = true;
      _pointSize = 6.0;

      _showChartTypeToggle = false;
      _showVolume = true;
      _showVolumeBelow = true;
      _volumeBarHeightRatio = 0.5;
      _volumeAreaHeightRatio = 0.15;
      _volumeBarVerticalOffset = 20;
      _volumeBarWidth = 10;
      _volumeBarOpacity = 0.6;
      _showVolumeTooltip = true;
      _showGrid = false;
      _autoHorizontalGridLines = 3;
      _autoVerticalGridLines = 3;
      _candleWidth = 10.0;
      _wickWidth = 2.0;
      _forceYAxisFromZero = true;
      _singleCrosshair = false;
      _areaTopOpacity = 0.5;
      _areaBottomOpacity = 0.0;
      _xSpanSlots = 35;
      _padding = const EdgeInsets.fromLTRB(10, 10, 60, 10);
      _yAxisTitleGap = 10.0;
      _xAxisTitleGap = 25.0;
      _xAxisLabelGap = 8.0;
      _yAxisLabelGap = 8.0;
      _yAxisPosition = YAxisPosition.right;
      _xAxisPosition = XAxisPosition.top;
      _keyEventMarkerSize = 10.0;
      _yAxisOpacity = 0.50;
      _xAxisOpacity = 0.50;
      _xAxisStrokeWidth = 3.00;
      _yAxisStrokeWidth = 3.00;
      _yAxisMaxOffset = 50.0;
      _gridStrokeWidth = 0.5;
      _gridOpacity = 1.0;
      _showVerticalLinesAtEveryLabels = false;
      _defaultLineWidth = 2.0;
      _keyEventMarkerVerticalOffset = 18.0;
      _keyEventMarkerMinHoverRadius = 15.0;
      _volumeTooltipBorderRadiusState = 6.0;
      _volumeTooltipOpacityState = 0.9;
      _showKeyEventMarkersState = true;
      _animationDurationMs = 1500;
      _showPointTooltipOnHover = true;
      _showDragTooltip = true;
    });
  }
}

class _TransparencyCheckerboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckerboardPainter(),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const squareSize = 12.0;
    final light = Paint()..color = const Color(0xFFE6E6E6);
    final dark = Paint()..color = const Color(0xFFCCCCCC);

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isDark = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        final rect = Rect.fromLTWH(x, y, squareSize, squareSize);
        canvas.drawRect(rect, isDark ? dark : light);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
