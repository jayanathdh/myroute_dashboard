import 'package:flutter/material.dart';
import 'package:myroute_web/advertisement.dart';
import 'package:myroute_web/bus_page.dart';
import 'package:myroute_web/notification.dart';
import 'package:myroute_web/user_manage.dart';

class DashboardPage extends StatefulWidget {
  final String userRole;
  const DashboardPage({super.key, required this.userRole});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Default පිටුව තෝරාගැනීම (Role එක අනුව මුලින්ම පෙනෙන පිටුව)
    if (widget.userRole == 'Bus Operator') selectedIndex = 1; // Bus Page
    if (widget.userRole == 'Staff') selectedIndex = 2; // Notification Page
  }

  // Role එක අනුව පෙන්විය යුතු පිටුව තීරණය කිරීම
  Widget _getSelectedPage() {
    switch (selectedIndex) {
      case 0:
        return const AdvertisementForm();
      case 1:
        return const BusPage();
      case 2:
        return const NotificationPage();
      case 3:
        return const UserManagementPage();
      default:
        return const Center(child: Text("Welcome"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            userRole: widget.userRole,
            selectedIndex: selectedIndex,
            onItemSelected: (index) => setState(() => selectedIndex = index),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF1A1F24),
              child: _getSelectedPage(),
            ),
          ),
        ],
      ),
    );
  }
}

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String userRole;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    bool isAdmin = userRole == 'Admin';
    bool isOperator = userRole == 'Bus Operator';
    bool isStaff = userRole == 'Staff';

    return Container(
      width: 260,
      color: const Color(0xFF263238),
      child: Column(
        children: [
          const DrawerHeader(
            child: Center(
              child: Text(
                'MyRoute',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // --- Role Based Menu Items ---

          // 1. Advertisement (Admin ට පමණයි)
          if (isAdmin) buildMenuItem(Icons.ads_click, 'Advertisement', 0),

          // 2. Bus (Admin සහ Bus Operator ට පමණයි)
          if (isAdmin || isOperator)
            buildMenuItem(Icons.directions_bus, 'Bus', 1),

          // 3. Notification (Admin සහ Staff ට පමණයි)
          if (isAdmin || isStaff)
            buildMenuItem(Icons.newspaper, 'Notification', 2),

          // 4. User Management (Admin ට පමණයි)
          if (isAdmin)
            buildMenuItem(Icons.manage_accounts, 'User Management', 3),

          const Spacer(),
          // Logout Button එකක් තිබීම වැදගත්
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () => Navigator.of(context).pop(), // හෝ Auth SignOut
          ),
          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Text(
              'Version 1.0',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMenuItem(IconData icon, String title, int index) {
    final isSelected = index == selectedIndex;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.blue : Colors.white70),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => onItemSelected(index),
      ),
    );
  }
}
