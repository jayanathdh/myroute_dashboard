import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _routeInputController =
      TextEditingController(); // තනි Route එකක් Type කිරීමට

  List<String> selectedRoutes = []; // එකතු කරන Route Numbers තබා ගැනීමට
  String selectedRole = 'Staff';
  final List<String> roles = ['Admin', 'Bus Operator', 'Staff'];
  bool isLoading = false;
  String? editingUid;

  // --- Route එකක් List එකට එකතු කිරීම ---
  void _addRouteToList() {
    String route = _routeInputController.text.trim();
    if (route.isNotEmpty && !selectedRoutes.contains(route)) {
      setState(() {
        selectedRoutes.add(route);
        _routeInputController.clear();
      });
    }
  }

  // --- List එකෙන් Route එකක් ඉවත් කිරීම ---
  void _removeRoute(String route) {
    setState(() {
      selectedRoutes.remove(route);
    });
  }

  // --- Save or Update User ---
  Future<void> _saveUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      try {
        if (editingUid == null) {
          UserCredential userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: _emailController.text.trim(),
                password: _passwordController.text.trim(),
              );

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
                'uid': userCredential.user!.uid,
                'name': _nameController.text.trim(),
                'email': _emailController.text.trim(),
                'routes': selectedRoutes, // List එකක් ලෙස Save වේ
                'role': selectedRole,
                'createdAt': FieldValue.serverTimestamp(),
              });
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(editingUid)
              .update({
                'name': _nameController.text.trim(),
                'routes': selectedRoutes, // List එකක් ලෙස Update වේ
                'role': selectedRole,
              });
        }

        _clearFields();
        _showSnackBar("Success!");
      } catch (e) {
        _showSnackBar("Error: ${e.toString()}");
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _deleteUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      _showSnackBar("User Deleted!");
    } catch (e) {
      _showSnackBar("Delete Error: $e");
    }
  }

  void _editUser(Map<String, dynamic> userData) {
    setState(() {
      editingUid = userData['uid'];
      _nameController.text = userData['name'] ?? '';
      _emailController.text = userData['email'] ?? '';
      selectedRoutes = List<String>.from(
        userData['routes'] ?? [],
      ); // Firestore List එක මෙහාට ගැනීම
      selectedRole = userData['role'] ?? 'Staff';
    });
  }

  void _clearFields() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _routeInputController.clear();
    selectedRoutes = [];
    editingUid = null;
    selectedRole = 'Staff';
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: _buildForm(),
            ),
          ),
          Expanded(flex: 3, child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF263238),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editingUid == null ? "Register User" : "Edit User",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField("Full Name", Icons.person, _nameController),
            const SizedBox(height: 15),
            _buildTextField(
              "Email",
              Icons.email,
              _emailController,
              enabled: editingUid == null,
            ),
            const SizedBox(height: 15),

            // --- Route Input Area ---
            const Text(
              "Assigned Routes",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    "Enter Route No",
                    Icons.directions_bus,
                    _routeInputController,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addRouteToList,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // පෙන්වන Route Chips ලැයිස්තුව
            Wrap(
              spacing: 8,
              children: selectedRoutes
                  .map(
                    (r) => Chip(
                      label: Text(r, style: const TextStyle(fontSize: 12)),
                      onDeleted: () => _removeRoute(r),
                      backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                      labelStyle: const TextStyle(color: Colors.white),
                      deleteIconColor: Colors.redAccent,
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 15),
            if (editingUid == null)
              _buildTextField(
                "Password",
                Icons.lock,
                _passwordController,
                isObscure: true,
              ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              dropdownColor: const Color(0xFF263238),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Role",
                prefixIcon: Icon(Icons.security, color: Colors.blueAccent),
              ),
              items: roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) => setState(() => selectedRole = val!),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: isLoading ? null : _saveUser,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(
                  editingUid == null ? "SAVE USER" : "UPDATE USER",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            if (editingUid != null)
              Center(
                child: TextButton(
                  onPressed: _clearFields,
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var user =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            List routes = user['routes'] ?? [];
            return Card(
              color: const Color(0xFF263238),
              child: ListTile(
                title: Text(
                  user['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['email'],
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Routes: ${routes.join(', ')}",
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editUser(user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteUser(user['uid']),
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

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool isObscure = false,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      enabled: enabled,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
      ),
    );
  }
}
