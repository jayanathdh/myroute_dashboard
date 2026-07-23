import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BusStopsPage extends StatefulWidget {
  const BusStopsPage({super.key});

  @override
  State<BusStopsPage> createState() => _BusStopsPageState();
}

class _BusStopsPageState extends State<BusStopsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  String _searchQuery = "";
  String _selectedType = "Bus Halt";

  // නම ID එකක් බවට පත් කරන ආකාරය
  String _toStopId(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  // දත්ත සුරැකීම (Duplicate වැළැක්වීම සමඟ)
  Future<void> _saveBusStop() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final stopId = _toStopId(name);

    final docRef = FirebaseFirestore.instance
        .collection('bus_stops')
        .doc(stopId);

    // දැනටමත් මෙම නමින් (ID එකෙන්) දත්තයක් පවතීදැයි පරීක්ෂා කිරීම
    final existing = await docRef.get();
    if (existing.exists) {
      if (!mounted) return;
      _showSnackBar(
        "This bus stop already exists. Please use a different name.",
        isError: true,
      );
      return;
    }

    await docRef.set({
      'name': name,
      'type': _selectedType,
      'created_at': FieldValue.serverTimestamp(),
    });

    _nameController.clear();
    // Save කළ පසු සෙවුම (Search) ඉවත් කිරීම
    setState(() {
      _selectedType = "Bus Halt";
      _searchQuery = "";
    });
    _showSnackBar("Saved successfully.");
  }

  Future<void> _deleteBusStop(String stopId) async {
    await FirebaseFirestore.instance
        .collection('bus_stops')
        .doc(stopId)
        .delete();
    _showSnackBar("Deleted successfully.");
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.indigoAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        cardColor: const Color(0xFF161618),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF212123),
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Bus Stop Management",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF0F0F0F),
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // වම් පස: දත්ත ඇතුළත් කරන කොටස
              Expanded(flex: 4, child: _buildInputCard()),
              const SizedBox(width: 20),
              // දකුණු පස: ලැයිස්තුව
              Expanded(flex: 6, child: _buildListSection()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Add New Bus Stop",
              style: TextStyle(
                color: Color(0xFF5E72E4),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 25),
            // නම ටයිප් කරන විටම සෙවීම සක්‍රිය කර ඇත (onChanged)
            TextFormField(
              controller: _nameController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase().trim();
                });
              },
              decoration: const InputDecoration(
                labelText: "Bus Stop Name",
                prefixIcon: Icon(
                  Icons.location_on,
                  size: 18,
                  color: Color(0xFF5E72E4),
                ),
              ),
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? "නම ඇතුළත් කරන්න"
                  : null,
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              dropdownColor: const Color(0xFF212123),
              decoration: const InputDecoration(labelText: "Stop Type"),
              items: [
                "Bus Stand",
                "Bus Halt",
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) =>
                  setState(() => _selectedType = v ?? _selectedType),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveBusStop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E72E4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "SAVE BUS STOP",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchQuery.isEmpty
                      ? "Existing Bus Stops"
                      : "Search Results",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Icon(
                  Icons.list_alt,
                  color: Colors.indigoAccent,
                  size: 20,
                ),
              ],
            ),
          ),
          Expanded(child: _buildStopsList()),
        ],
      ),
    );
  }

  Widget _buildStopsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bus_stops')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading data"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ඇතුළත් කරන නමට අනුව ලැයිස්තුව පෙරීම (Filter) කිරීම මෙහිදී සිදු වේ
        final docs = snapshot.data!.docs.where((doc) {
          final name = (doc['name'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text("No stops found", style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF212123),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF161618),
                  child: Icon(
                    data['type'] == "Bus Stand"
                        ? Icons.business
                        : Icons.directions_bus,
                    size: 18,
                    color: const Color(0xFF5E72E4),
                  ),
                ),
                title: Text(
                  data['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  data['type'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _deleteBusStop(doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
