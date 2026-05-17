import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  final int totalMedicines;
  final int expiredCount;
  final int expiringSoonCount;
  final int okCount;
  final Map<String, double> supplierSpend; // supplier name → total spend

  const AnalyticsScreen({
    super.key,
    required this.totalMedicines,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.okCount,
    required this.supplierSpend,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF0F4FF),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('MEDICINE EXPIRY STATUS'),
          const SizedBox(height: 12),
          _expiryPieChart(),
          const SizedBox(height: 24),
          _sectionLabel('SPEND BY SUPPLIER'),
          const SizedBox(height: 12),
          _supplierBarChart(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0D47A1),
            letterSpacing: 1.1));
  }

  Widget _expiryPieChart() {
    final sections = [
      PieChartSectionData(
        value: okCount.toDouble(),
        color: Colors.green,
        title: okCount > 0 ? 'OK\n$okCount' : '',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      PieChartSectionData(
        value: expiringSoonCount.toDouble(),
        color: Colors.orange,
        title: expiringSoonCount > 0 ? 'Soon\n$expiringSoonCount' : '',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      PieChartSectionData(
        value: expiredCount.toDouble(),
        color: Colors.red,
        title: expiredCount > 0 ? 'Expired\n$expiredCount' : '',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ].where((s) => s.value > 0).toList();

    if (sections.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 3,
            )),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend('OK', Colors.green),
              const SizedBox(width: 16),
              _legend('Expiring Soon', Colors.orange),
              const SizedBox(width: 16),
              _legend('Expired', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _supplierBarChart() {
    if (supplierSpend.isEmpty) {
      return const Center(child: Text('No invoice data yet'));
    }

    final entries = supplierSpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList(); // top 5 suppliers

    final maxY = top.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        height: 220,
        child: BarChart(BarChartData(
          maxY: maxY * 1.2,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (v, _) => Text(
                  '₱${v.toInt()}',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= top.length) return const SizedBox();
                  final name = top[i].key;
                  final short = name.length > 8 ? '${name.substring(0, 8)}…' : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(short,
                        style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: List.generate(top.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: top[i].value,
                color: const Color(0xFF0D47A1),
                width: 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ]);
          }),
        )),
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}