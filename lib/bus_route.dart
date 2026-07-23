import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // අලුතින් එකතු කළා
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BusRoutesPage extends StatefulWidget {
  const BusRoutesPage({super.key});

  @override
  State<BusRoutesPage> createState() => _BusRoutesPageState();
}

class _BusRoutesPageState extends State<BusRoutesPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _routeNumberController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _routeListSearchController =
      TextEditingController();

  final TextEditingController _polylineController = TextEditingController();

  List<String> _selectedStops = [];
  String _searchQuery = "";
  String _routeFilter = "";
  bool _isRouteDuplicate = false;

  String? _selectedFrom;
  String? _selectedTo;
  String? _selectedRouteType;
  String? _editingRouteId;

  Future<void> _checkRouteNumber(String value) async {
    if (value.isEmpty || _editingRouteId != null) {
      setState(() => _isRouteDuplicate = false);
      return;
    }
    final query = await FirebaseFirestore.instance
        .collection('bus_routes')
        .where('route_number', isEqualTo: value.trim())
        .get();
    setState(() {
      _isRouteDuplicate = query.docs.isNotEmpty;
    });
  }

  Future<void> _saveBusRoute() async {
    if (_isRouteDuplicate) {
      _showSnackBar("Cannot save. Route Number already exists!", isError: true);
      return;
    }

    if (_formKey.currentState!.validate() &&
        _selectedStops.isNotEmpty &&
        _selectedFrom != null &&
        _selectedTo != null &&
        _selectedRouteType != null) {
      String routeNo = _routeNumberController.text.trim();
      String polyline = _polylineController.text.trim();

      Future<void> createEntry(
        String from,
        String to,
        List<String> stops,
        String pathData,
      ) async {
        final data = {
          'route_number': routeNo,
          'from': from,
          'to': to,
          'stops': stops,
          'route_type': _selectedRouteType,
          'polyline_path': pathData,
          'created_at': FieldValue.serverTimestamp(),
        };

        DocumentReference ref = await FirebaseFirestore.instance
            .collection('bus_routes')
            .add(data);
        await FirebaseFirestore.instance
            .collection('bus_times')
            .doc(ref.id)
            .set({
              'route_id': ref.id,
              'route_no': routeNo,
              'from': from,
              'to': to,
              'stops': stops,
              'route_type': _selectedRouteType,
              'buses': [],
              'updated_at': FieldValue.serverTimestamp(),
            });
      }

      if (_editingRouteId == null) {
        await createEntry(
          _selectedFrom!,
          _selectedTo!,
          _selectedStops,
          polyline,
        );
        List<String> reverseStops = List.from(_selectedStops.reversed);
        await createEntry(_selectedTo!, _selectedFrom!, reverseStops, polyline);
        _showSnackBar("Both directions added successfully!");
      } else {
        await FirebaseFirestore.instance
            .collection('bus_routes')
            .doc(_editingRouteId!)
            .update({
              'route_number': routeNo,
              'from': _selectedFrom,
              'to': _selectedTo,
              'stops': _selectedStops,
              'route_type': _selectedRouteType,
              'polyline_path': polyline,
            });
        _showSnackBar("Route updated successfully!");
      }
      _clearForm();
    } else {
      _showSnackBar("Please fill all fields correctly!", isError: true);
    }
  }

  void _clearForm() {
    _routeNumberController.clear();
    _searchController.clear();
    _polylineController.clear();
    setState(() {
      _selectedStops = [];
      _searchQuery = "";
      _selectedFrom = null;
      _selectedTo = null;
      _selectedRouteType = null;
      _editingRouteId = null;
      _isRouteDuplicate = false;
    });
  }

  void _editRoute(DocumentSnapshot doc) {
    setState(() {
      _editingRouteId = doc.id;
      _routeNumberController.text = doc['route_number'];
      _selectedFrom = doc['from'];
      _selectedTo = doc['to'];
      _selectedStops = List<String>.from(doc['stops']);
      _selectedRouteType = doc['route_type'];

      var data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('polyline_path')) {
        _polylineController.text = data['polyline_path'];
      } else {
        _polylineController.clear();
      }

      _isRouteDuplicate = false;
    });
  }

  Future<void> _deleteRoute(String id) async {
    await FirebaseFirestore.instance.collection('bus_routes').doc(id).delete();
    await FirebaseFirestore.instance.collection('bus_times').doc(id).delete();
    _showSnackBar("Route deleted successfully!");
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red[700] : Colors.teal[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // අලුතින් එකතු කළ Map Editor Dialog එක
  void _showMapEditorDialog() {
    String tempPolyline = _polylineController.text;
    List<LatLng> mapPoints = [];
    Set<Polyline> polylines = {};
    bool isLoading = false;

    void loadExistingPolyline() {
      if (tempPolyline.isNotEmpty) {
        try {
          var decoded = decodePolyline(tempPolyline);
          mapPoints = decoded
              .map((p) => LatLng(p[0].toDouble(), p[1].toDouble()))
              .toList();
          polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: mapPoints,
              color: Colors.blueAccent,
              width: 5,
            ),
          );
        } catch (e) {
          debugPrint("Error decoding polyline: $e");
        }
      }
    }

    // ආරම්භයේදීම පාරක් තිබේ නම් එය පෙන්වීම
    loadExistingPolyline();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // --- ස්වයංක්‍රීයව පාර ඇඳීමේ Function එක ---
            Future<void> fetchRouteFromAPI() async {
              if (_selectedFrom == null || _selectedTo == null) {
                _showSnackBar(
                  "Please select 'Starting From' and 'Destination To' first!",
                  isError: true,
                );
                return;
              }

              setStateDialog(() => isLoading = true);

              try {
                // මෙතැනට ඔබගේ API Key එක ලබා දෙන්න
                String apiKey = "AIzaSyDHs7FD6QGS0F4t4iJ4ITFB5Xaga7lu2Ls";

                String origin = Uri.encodeComponent(_selectedFrom!);
                String destination = Uri.encodeComponent(_selectedTo!);

                // තෝරාගත් Bus Stops හරහා පාර සෑදීම සඳහා (Waypoints)
                String waypoints = "";
                if (_selectedStops.isNotEmpty) {
                  waypoints =
                      "&waypoints=" +
                      _selectedStops
                          .map((s) => Uri.encodeComponent(s))
                          .join("|");
                }

                String url =
                    "https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination$waypoints&key=$apiKey";

                var response = await http.get(Uri.parse(url));
                var data = jsonDecode(response.body);

                if (data['status'] == 'OK') {
                  String encodedPath =
                      data['routes'][0]['overview_polyline']['points'];
                  setStateDialog(() {
                    tempPolyline = encodedPath;
                    mapPoints.clear();
                    polylines.clear();
                    loadExistingPolyline(); // ලබාගත් පාර සිතියමේ පෙන්වීම
                  });
                  _showSnackBar("Route automatically generated!");
                } else {
                  _showSnackBar(
                    "Could not find route: ${data['status']}",
                    isError: true,
                  );
                }
              } catch (e) {
                _showSnackBar("Error fetching route: $e", isError: true);
              } finally {
                setStateDialog(() => isLoading = false);
              }
            }

            return Dialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.map, color: Colors.indigoAccent),
                            SizedBox(width: 12),
                            Text(
                              "Map Route Editor",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Draw manually or auto-generate route.",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        Row(
                          children: [
                            if (isLoading)
                              const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              ),
                            TextButton.icon(
                              onPressed: isLoading ? null : fetchRouteFromAPI,
                              icon: const Icon(
                                Icons.auto_awesome,
                                color: Colors.amberAccent,
                                size: 18,
                              ),
                              label: const Text(
                                "Auto-Generate",
                                style: TextStyle(color: Colors.amberAccent),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setStateDialog(() {
                                  mapPoints.clear();
                                  polylines.clear();
                                  tempPolyline = "";
                                });
                              },
                              icon: const Icon(
                                Icons.clear_all,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              label: const Text(
                                "Clear",
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Map Area
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GoogleMap(
                            initialCameraPosition: const CameraPosition(
                              target: LatLng(7.8731, 80.7718),
                              zoom: 7.0,
                            ),
                            myLocationEnabled: true,
                            mapToolbarEnabled: true,
                            zoomControlsEnabled: true,
                            polylines: polylines,
                            onTap: (LatLng point) {
                              // අතින් පාර ඇඳීම
                              setStateDialog(() {
                                mapPoints.add(point);
                                polylines.add(
                                  Polyline(
                                    polylineId: const PolylineId('route'),
                                    points: mapPoints,
                                    color: Colors.blueAccent,
                                    width: 5,
                                  ),
                                );
                                List<List<num>> coordinates = mapPoints
                                    .map((p) => [p.latitude, p.longitude])
                                    .toList();
                                tempPolyline = encodePolyline(coordinates);
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: TextEditingController(text: tempPolyline),
                      readOnly: true,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        labelText: "Encoded Polyline String",
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "CANCEL",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _polylineController.text = tempPolyline;
                            });
                            Navigator.pop(context);
                            _showSnackBar("Route path updated from map!");
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigoAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("CONFIRM & SAVE PATH"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Route Management",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: true,
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildInputSection(),
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildRouteSearchHeader(),
                    Expanded(child: _buildRouteList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editingRouteId == null ? "New Route Details" : "Modify Route",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigoAccent,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _routeNumberController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Route Number",
                  prefixIcon: const Icon(
                    Icons.tag,
                    size: 20,
                    color: Colors.indigoAccent,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  errorText: _isRouteDuplicate
                      ? "This route number already exists!"
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isRouteDuplicate
                          ? Colors.red
                          : Colors.transparent,
                    ),
                  ),
                ),
                onChanged: _checkRouteNumber,
                validator: (val) => val!.isEmpty ? "Required field" : null,
              ),
              const SizedBox(height: 16),
              _buildStopDropdown(
                "Starting From",
                _selectedFrom,
                (val) => setState(() => _selectedFrom = val),
              ),
              const SizedBox(height: 16),
              _buildStopDropdown(
                "Destination To",
                _selectedTo,
                (val) => setState(() => _selectedTo = val),
              ),
              const SizedBox(height: 16),
              _buildTypeDropdown(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _polylineController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Route Path (Polyline Data)",
                  hintText: "Paste encoded polyline or use map",
                  prefixIcon: const Icon(
                    Icons.map_outlined,
                    size: 20,
                    color: Colors.indigoAccent,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.edit_location_alt,
                      color: Colors.indigoAccent,
                    ),
                    onPressed: _showMapEditorDialog,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const Divider(color: Colors.white10, height: 40),
              const Text(
                "Route Path (Bus Stops)",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              _buildStopSearchField(),
              if (_searchQuery.isNotEmpty) _buildSearchResults(),
              const SizedBox(height: 12),
              _buildSelectedStopsWrap(),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isRouteDuplicate ? null : _saveBusRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRouteDuplicate
                        ? Colors.grey
                        : Colors.indigoAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _editingRouteId == null
                        ? "SAVE ROUTE (BOTH DIRECTIONS)"
                        : "UPDATE CHANGES",
                  ),
                ),
              ),
              if (_editingRouteId != null)
                TextButton(
                  onPressed: _clearForm,
                  child: const Text(
                    "Cancel Edit",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: "Find & add stops...",
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
    );
  }

  Widget _buildSelectedStopsWrap() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _selectedStops
          .map(
            (s) => Chip(
              label: Text(
                s,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              onDeleted: () => setState(() => _selectedStops.remove(s)),
              backgroundColor: Colors.indigoAccent.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRouteSearchHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus, color: Colors.indigoAccent),
              const SizedBox(width: 12),
              const Text(
                "Existing Routes",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                _routeFilter.isEmpty ? 'All' : 'Filtered',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _routeListSearchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Filter by No, Start or End location...",
              prefixIcon: const Icon(Icons.filter_alt, size: 20),
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) =>
                setState(() => _routeFilter = val.toLowerCase()),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bus_routes')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs.where((d) {
          var rNo = d['route_number'].toString().toLowerCase();
          var from = d['from'].toString().toLowerCase();
          var to = d['to'].toString().toLowerCase();
          return rNo.contains(_routeFilter) ||
              from.contains(_routeFilter) ||
              to.contains(_routeFilter);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index];
            List<dynamic> stops = data['stops'] ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigoAccent.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        data['route_number'],
                        style: const TextStyle(
                          color: Colors.indigoAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      "${data['from']} ➔ ${data['to']}",
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    subtitle: Text(
                      "${data['route_type']} • ${stops.length} Stops",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () => _editRoute(data),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteRoute(data.id),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: stops
                            .map(
                              (s) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  s.toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- සම්පූර්ණ කරන ලද කේත කොටස් පහතින් දැක්වේ ---

  Widget _buildStopDropdown(
    String label,
    String? value,
    Function(String?) onChanged,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bus_stops')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var items = snapshot.data!.docs
            .map((d) => d['name'] as String)
            .toList();

        return DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: const Color(0xFF2C2C2C),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (val) => val == null ? "Required field" : null,
          dropdownColor: const Color(0xFF2C2C2C),
          style: const TextStyle(color: Colors.white),
        );
      },
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRouteType,
      items: [
        'Normal',
        'Semi-Luxury',
        'Luxury',
        'Super Luxury',
      ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (val) => setState(() => _selectedRouteType = val),
      decoration: InputDecoration(
        labelText: "Route Type",
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (val) => val == null ? "Required field" : null,
      dropdownColor: const Color(0xFF2C2C2C),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bus_stops').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        var results = snapshot.data!.docs.where((d) {
          var name = (d['name'] as String).toLowerCase();
          return name.contains(_searchQuery) &&
              !_selectedStops.contains(d['name']);
        }).toList();

        if (results.isEmpty) return const SizedBox();

        return Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (context, index) {
              var name = results[index]['name'] as String;
              return ListTile(
                title: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                trailing: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.indigoAccent,
                  size: 20,
                ),
                onTap: () {
                  setState(() {
                    _selectedStops.add(name);
                    _searchController.clear();
                    _searchQuery = "";
                  });
                },
              );
            },
          ),
        );
      },
    );
  }
}
