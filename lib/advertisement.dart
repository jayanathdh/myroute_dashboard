import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Storage එකට
import 'package:image_picker/image_picker.dart'; // Image select කරන්න
import 'package:flutter/foundation.dart';

class AdvertisementForm extends StatefulWidget {
  const AdvertisementForm({super.key});

  @override
  State<AdvertisementForm> createState() => _AdvertisementFormState();
}

class _AdvertisementFormState extends State<AdvertisementForm> {
  final _formKey = GlobalKey<FormState>();

  // Image handling variables
  Uint8List? _webImage; // වෙබ් එකේ select කරපු image එකේ data
  String? _uploadedImageUrl; // Upload උනාට පස්සේ එන link එක

  DateTime? startTime;
  DateTime? endTime;
  bool isSaving = false;
  String? editingAdId;

  // Image එක select කරන function එක
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      var f = await image.readAsBytes(); // වෙබ් එකට ගැලපෙන විදිහට convert කිරීම
      setState(() {
        _webImage = f;
        _uploadedImageUrl =
            null; // අලුත් image එකක් ගත්ත නිසා පරණ link එක අයින් කරනවා
      });
    }
  }

  // Firebase Storage එකට upload කරන function එක
  Future<String?> uploadImageToStorage() async {
    if (_webImage == null) {
      return _uploadedImageUrl; // අලුත් image එකක් නැත්නම් පරණ link එකම තියන්න
    }

    try {
      // නමක් හදනවා (Current Time එක පාවිච්චි කරලා)
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child(
        'advertisements/$fileName.jpg',
      );

      // Upload කරනවා
      UploadTask uploadTask = ref.putData(_webImage!);
      TaskSnapshot snapshot = await uploadTask;

      // Upload උනාට පස්සේ Link එක ගන්නවා
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Upload Error: $e");
      return null;
    }
  }

  Future<DateTime?> pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted) return null;

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (!mounted) return null;

      if (pickedTime != null) {
        return DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      }
    }
    return null;
  }

  Future<void> saveAd() async {
    // Validation: Image එකක් තියෙන්නම ඕන
    if (_webImage == null && _uploadedImageUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select an image")));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      // 1. මුලින්ම Image එක Upload කරගන්නවා
      String? imageUrl = await uploadImageToStorage();

      if (imageUrl == null) {
        throw "Image upload failed";
      }

      // 2. ඊට පස්සේ Firestore එකේ save කරනවා
      Map<String, dynamic> data = {
        'imageUrl': imageUrl,
        'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
        'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      };

      if (editingAdId == null) {
        // Add new
        await FirebaseFirestore.instance.collection('advertisements').add(data);
      } else {
        // Update existing
        await FirebaseFirestore.instance
            .collection('advertisements')
            .doc(editingAdId)
            .update(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editingAdId == null
                  ? "Advertisement saved successfully"
                  : "Advertisement updated successfully",
            ),
          ),
        );

        // Form එක Reset කිරීම
        setState(() {
          _webImage = null;
          _uploadedImageUrl = null;
          startTime = null;
          endTime = null;
          editingAdId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  void loadAdForEdit(DocumentSnapshot doc) {
    setState(() {
      editingAdId = doc.id;
      _uploadedImageUrl = doc['imageUrl']; // පරණ image link එක පෙන්නන්න
      _webImage = null; // අලුත් image එකක් select කරලා නෑ
      startTime = (doc['startTime'] as Timestamp?)?.toDate();
      endTime = (doc['endTime'] as Timestamp?)?.toDate();
    });
  }

  Future<void> deleteAd(String id) async {
    await FirebaseFirestore.instance
        .collection('advertisements')
        .doc(id)
        .delete();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Advertisement deleted")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Advertisements")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Image Picker Area Start ---
                      const Text(
                        "Advertisement Image",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: pickImage,
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _webImage != null
                              ? Image.memory(
                                  _webImage!,
                                  fit: BoxFit.cover,
                                ) // අලුතින් තෝරාගත් පින්තූරය
                              : (_uploadedImageUrl != null &&
                                    _uploadedImageUrl!.isNotEmpty)
                              ? Image.network(
                                  _uploadedImageUrl!,
                                  fit: BoxFit.cover,
                                ) // කලින් save කරපු පින්තූරය (Edit කරද්දි)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                    Text("Click to select image"),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // --- Image Picker Area End ---

                      // Start Time
                      TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "Start Time",
                          suffixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(
                          text: startTime != null ? startTime.toString() : "",
                        ),
                        onTap: () async {
                          DateTime? picked = await pickDateTime();
                          if (picked != null && mounted) {
                            setState(() => startTime = picked);
                          }
                        },
                        validator: (_) =>
                            startTime == null ? "Please set start time" : null,
                      ),
                      const SizedBox(height: 16),

                      // End Time
                      TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "End Time",
                          suffixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(
                          text: endTime != null ? endTime.toString() : "",
                        ),
                        onTap: () async {
                          DateTime? picked = await pickDateTime();
                          if (picked != null && mounted) {
                            setState(() => endTime = picked);
                          }
                        },
                        validator: (_) =>
                            endTime == null ? "Please set end time" : null,
                      ),
                      const SizedBox(height: 20),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  editingAdId == null
                                      ? Icons.save
                                      : Icons.update,
                                ),
                          label: Text(
                            isSaving
                                ? "Uploading & Saving..."
                                : (editingAdId == null
                                      ? "Save Advertisement"
                                      : "Update Advertisement"),
                          ),
                          onPressed: isSaving ? null : saveAd,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Saved Ads List
            const Text(
              "Saved Advertisements",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('advertisements')
                  .orderBy('startTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text("Error loading ads");
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final ads = snapshot.data!.docs;
                if (ads.isEmpty) return const Text("No advertisements saved.");

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ads.length,
                  itemBuilder: (context, index) {
                    final ad = ads[index];
                    final start =
                        (ad['startTime'] as Timestamp?)?.toDate().toString() ??
                        "";
                    final end =
                        (ad['endTime'] as Timestamp?)?.toDate().toString() ??
                        "";

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Image.network(
                          ad['imageUrl'],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        ),
                        title: Text("Ad ${index + 1}"),
                        subtitle: Text("From: $start\nTo: $end"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => loadAdForEdit(ad),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteAd(ad.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
