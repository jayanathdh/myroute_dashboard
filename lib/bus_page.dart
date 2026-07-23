import 'package:flutter/material.dart';
import 'package:myroute_web/bus_route.dart';
import 'package:myroute_web/bus_stops.dart';
import 'package:myroute_web/save_bus_times.dart';
import 'package:myroute_web/ai_timetable_enter.dart';

class BusPage extends StatelessWidget {
  const BusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        cardColor: const Color(0xFF161618),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Bus Administration",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF0F0F0F),
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _buildMenuCard(
                  context,
                  title: "Bus Stops",
                  subtitle: "Manage halt locations",
                  icon: Icons.location_on,
                  color: const Color(0xFF5E72E4),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BusStopsPage(),
                    ),
                  ),
                ),
                _buildMenuCard(
                  context,
                  title: "Bus Routes",
                  subtitle: "Define paths and stops",
                  icon: Icons.alt_route,
                  color: Colors.orangeAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BusRoutesPage(),
                    ),
                  ),
                ),
                _buildMenuCard(
                  context,
                  title: "Timetables",
                  subtitle: "Save bus schedules",
                  icon: Icons.schedule,
                  color: Colors.tealAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BusTimetableListPage(),
                    ),
                  ),
                ),
                _buildMenuCard(
                  context,
                  title: "AI Timetable Enter",
                  subtitle: "Generate timetable using AI",
                  icon: Icons.auto_awesome,
                  color: Colors.purpleAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AITimetableEnterPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10, width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
