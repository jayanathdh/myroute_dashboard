import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusTimetableListPage extends StatefulWidget {
  const BusTimetableListPage({super.key});

  @override
  State<BusTimetableListPage> createState() => _BusTimetableListPageState();
}

class _BusTimetableListPageState extends State<BusTimetableListPage> {
  final CollectionReference busTimesRef = FirebaseFirestore.instance.collection(
    'bus_times',
  );

  String? selectedRouteId;
  List<String> userAssignedRoutes = [];
  String userRole = 'Staff';
  bool isInitialLoading = true;

  // Add Bus Form Controllers & Variables
  final _busNumberController = TextEditingController();
  final _busTypeController = TextEditingController();
  final _ntcNumberController = TextEditingController();
  String _operator = 'NTC';
  String _dayType = 'Every day';
  List<String> _weekDays = [];
  Map<String, Map<String, dynamic>?> stopTimes = {};
  final List<String> allWeekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            userAssignedRoutes = List<String>.from(data['routes'] ?? []);
            userRole = data['role'] ?? 'Staff';
            isInitialLoading = false;
          });
        } else {
          setState(() => isInitialLoading = false);
        }
      } catch (e) {
        setState(() => isInitialLoading = false);
      }
    }
  }

  String _formatTime(Map<String, dynamic>? timeData) {
    if (timeData == null) return "Select Time";
    int h = timeData['hour'] ?? 0;
    int m = timeData['minute'] ?? 0;
    String p = timeData['period'] ?? '';
    return "$h:${m.toString().padLeft(2, '0')} $p";
  }

  // --- Add Bus Logic ---
  Future<void> _pickTime(String stop, StateSetter setModalState) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 30),
    );
    if (picked != null) {
      setModalState(() {
        stopTimes[stop] = {
          'hour': picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod,
          'minute': picked.minute,
          'period': picked.period == DayPeriod.am ? "AM" : "PM",
        };
      });
    }
  }

  // මෙහි editIndex parameter එක එකතු කර ඇත
  void _showAddBusSheet(
    Map<String, dynamic> routeData,
    String docId, {
    int? editIndex,
  }) {
    List<String> stops = List<String>.from(routeData['stops'] ?? []);

    if (editIndex == null) {
      // Reset fields for NEW bus
      _busNumberController.clear();
      _busTypeController.text = 'Normal';
      _ntcNumberController.clear();
      _operator = 'NTC';
      _dayType = 'Every day';
      _weekDays = [];
      stopTimes.clear();
      for (var stop in stops) {
        stopTimes[stop] = null;
      }
    } else {
      // Load existing data for EDITING
      var bus = routeData['buses'][editIndex];
      _busNumberController.text = bus['bus_number'] ?? '';
      _busTypeController.text = bus['bus_type'] ?? 'Normal';
      _ntcNumberController.text = bus['ntc_number'] ?? '';
      _operator = bus['operator'] ?? 'NTC';
      _dayType = bus['day_type'] ?? 'Every day';
      _weekDays = List<String>.from(bus['week_days'] ?? []);
      stopTimes = Map<String, Map<String, dynamic>?>.from(bus['times'] ?? {});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  editIndex == null ? "Add New Bus" : "Edit Bus",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextField(
                  controller: _busNumberController,
                  decoration: const InputDecoration(labelText: 'Bus Number'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _busTypeController.text.isEmpty
                      ? 'Normal'
                      : _busTypeController.text,
                  items: ['Normal', 'Luxury', 'Semi Luxury', 'Super Luxury']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) =>
                      setModalState(() => _busTypeController.text = val!),
                  decoration: const InputDecoration(labelText: 'Bus Type'),
                ),
                TextField(
                  controller: _ntcNumberController,
                  decoration: const InputDecoration(labelText: 'NTC Number'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _operator,
                  items: ['NTC', 'SLTB']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setModalState(() => _operator = val!),
                  decoration: const InputDecoration(labelText: 'Operator'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _dayType,
                  items: ['Every day', 'Odd days', 'Even days']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setModalState(() => _dayType = val!),
                  decoration: const InputDecoration(labelText: 'Day Type'),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Select Days:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: allWeekDays
                      .map(
                        (day) => FilterChip(
                          label: Text(day),
                          selected: _weekDays.contains(day),
                          onSelected: (selected) => setModalState(() {
                            selected
                                ? _weekDays.add(day)
                                : _weekDays.remove(day);
                          }),
                        ),
                      )
                      .toList(),
                ),
                const Divider(),
                const Text(
                  "Stop Times",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...stops.map(
                  (stop) => ListTile(
                    title: Text(stop),
                    subtitle: Text(_formatTime(stopTimes[stop])),
                    trailing: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () => _pickTime(stop, setModalState),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (_busNumberController.text.isEmpty) return;

                    Map<String, dynamic> busData = {
                      'bus_number': _busNumberController.text,
                      'bus_type': _busTypeController.text,
                      'ntc_number': _ntcNumberController.text,
                      'operator': _operator,
                      'day_type': _dayType,
                      'week_days': List.from(_weekDays),
                      'times': stopTimes,
                    };

                    List buses = List.from(routeData['buses'] ?? []);

                    if (editIndex == null) {
                      // ADD Mode
                      await busTimesRef.doc(docId).update({
                        'buses': FieldValue.arrayUnion([busData]),
                        'updated_at': FieldValue.serverTimestamp(),
                      });
                    } else {
                      // EDIT Mode
                      buses[editIndex] = busData;
                      await busTimesRef.doc(docId).update({
                        'buses': buses,
                        'updated_at': FieldValue.serverTimestamp(),
                      });
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            editIndex == null
                                ? "Bus added successfully!"
                                : "Bus updated successfully!",
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Text(
                    editIndex == null
                        ? "Save Bus Details"
                        : "Update Bus Details",
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- List & UI ---

  Future<void> _deleteBus(
    String docId,
    int busIndex,
    Map<String, dynamic> routeData,
  ) async {
    List buses = List.from(routeData['buses']);
    buses.removeAt(busIndex);
    await busTimesRef.doc(docId).update({'buses': buses});
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Bus deleted")));
      setState(() {});
    }
  }

  // --- Edit Button click කළ විට ක්‍රියාත්මක වන කොටස ---
  void _editBus(Map<String, dynamic> routeData, String docId, int busIndex) {
    // Dialog එකක් වෙනුවට දැන් Modal Sheet එකම open කරයි
    _showAddBusSheet(routeData, docId, editIndex: busIndex);
  }

  Widget _buildSelectedRouteTable(List<QueryDocumentSnapshot> routes) {
    final selectedRoute = routes.firstWhere(
      (route) => route.id == selectedRouteId,
    );
    final data = selectedRoute.data() as Map<String, dynamic>;
    final buses = List.from(data['buses'] ?? []);
    final stops = List<String>.from(data['stops'] ?? []);

    if (buses.isEmpty || stops.isEmpty) {
      return const Center(child: Text("No buses available"));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "${data['route_no']} : ${data['from']} ➜ ${data['to']} (${data['route_type']})",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Card(
              elevation: 4,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 25,
                    headingRowColor: WidgetStateProperty.all(
                      Colors.blue.shade50,
                    ),
                    columns: [
                      const DataColumn(label: Text("Bus No")),
                      const DataColumn(label: Text("Bus Type")),
                      const DataColumn(label: Text("NTC No")),
                      const DataColumn(label: Text("Operator")),
                      const DataColumn(label: Text("Day Type")),
                      const DataColumn(label: Text("Week Days")),
                      ...stops.map((s) => DataColumn(label: Text(s))),
                      const DataColumn(label: Text("Actions")),
                    ],
                    rows: buses.asMap().entries.map((entry) {
                      int busIndex = entry.key;
                      Map<String, dynamic> bus = Map<String, dynamic>.from(
                        entry.value,
                      );
                      Map times = Map.from(bus['times'] ?? {});
                      List weekDays = bus['week_days'] ?? [];
                      return DataRow(
                        cells: [
                          DataCell(Text(bus['bus_number'] ?? '-')),
                          DataCell(Text(bus['bus_type'] ?? '-')),
                          DataCell(Text(bus['ntc_number'] ?? '-')),
                          DataCell(Text(bus['operator'] ?? '-')),
                          DataCell(Text(bus['day_type'] ?? '-')),
                          DataCell(Text(weekDays.join(', '))),
                          ...stops.map(
                            (stop) => DataCell(Text(_formatTime(times[stop]))),
                          ),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _editBus(
                                    data,
                                    selectedRouteId!,
                                    busIndex,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteBus(
                                    selectedRouteId!,
                                    busIndex,
                                    data,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Query query = busTimesRef.orderBy('route_no');
    if (userRole != 'Admin') {
      if (userAssignedRoutes.isNotEmpty) {
        query = busTimesRef
            .where('route_no', whereIn: userAssignedRoutes)
            .orderBy('route_no');
      } else {
        return Scaffold(
          appBar: AppBar(title: const Text("Bus Timetables")),
          body: const Center(child: Text("No routes assigned.")),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Bus Timetables"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final routes = snapshot.data!.docs;
          if (routes.isEmpty) {
            return const Center(child: Text("No routes found"));
          }

          return Column(
            children: [
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: routes.length,
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    final data = route.data() as Map<String, dynamic>;
                    bool selected = selectedRouteId == route.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: InkWell(
                        onTap: () => setState(() => selectedRouteId = route.id),
                        child: Card(
                          color: selected ? Colors.blue : Colors.white,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.center,
                            child: Text(
                              data['route_no'] ?? '-',
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Expanded(
                child: selectedRouteId == null
                    ? const Center(child: Text("Select a route"))
                    : _buildSelectedRouteTable(routes),
              ),
            ],
          );
        },
      ),
      // --- Add Bus Button ---
      floatingActionButton: selectedRouteId != null
          ? StreamBuilder<DocumentSnapshot>(
              stream: busTimesRef.doc(selectedRouteId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return FloatingActionButton.extended(
                  onPressed: () => _showAddBusSheet(
                    snapshot.data!.data() as Map<String, dynamic>,
                    selectedRouteId!,
                  ),
                  label: const Text("Add Bus"),
                  icon: const Icon(Icons.add),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                );
              },
            )
          : null,
    );
  }
}
