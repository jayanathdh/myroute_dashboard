import 'dart:typed_data'; // For Web Image handling
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // For Storage
import 'package:image_picker/image_picker.dart'; // For Picking Images

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationAddPageState();
}

class _NotificationAddPageState extends State<NotificationPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  Uint8List? _selectedImageBytes;
  bool _loading = false;

  // --- 0. PICK IMAGE FUNCTION ---
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _selectedImageBytes = bytes);
    }
  }

  // --- 1. UPLOAD & ADD DATA ---
  Future<void> _addNotification() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title & Description required')),
      );
      return;
    }

    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }

    setState(() => _loading = true);

    try {
      // Upload image to Storage
      final fileName = 'notif_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(
        'notification_images/$fileName',
      );

      final uploadTask = ref.putData(_selectedImageBytes!);
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      // Add to Firestore
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': _titleController.text,
        'description': _descController.text,
        'image': imageUrl,
        'date': Timestamp.now(),
      });

      _titleController.clear();
      _descController.clear();
      setState(() => _selectedImageBytes = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- 2. DELETE DATA ---
  Future<void> _deleteNotification(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification deleted')));
    }
  }

  // --- 3. PICK IMAGE (FOR EDIT) ---
  Future<Uint8List?> _pickImageBytesForEdit() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    return await image.readAsBytes();
  }

  // --- 4. UPLOAD IMAGE (FOR EDIT) ---
  Future<String> _uploadEditedImage(Uint8List bytes) async {
    final fileName = 'notif_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(
      'notification_images/$fileName',
    );
    final snapshot = await ref.putData(bytes);
    return await snapshot.ref.getDownloadURL();
  }

  // --- 5. UPDATE DATA ---
  Future<void> _updateNotification({
    required String docId,
    required String newTitle,
    required String newDesc,
    String? newImageUrl,
  }) async {
    final data = <String, dynamic>{'title': newTitle, 'description': newDesc};
    if (newImageUrl != null) data['image'] = newImageUrl;

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update(data);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification updated')));
    }
  }

  // --- 6. EDIT DIALOG ---
  Future<void> _openEditDialog({
    required String docId,
    required Map<String, dynamic> item,
  }) async {
    final titleCtrl = TextEditingController(text: item['title'] ?? '');
    final descCtrl = TextEditingController(text: item['description'] ?? '');

    Uint8List? editedImageBytes;
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDState) {
            return AlertDialog(
              title: const Text("Edit Notification"),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descCtrl,
                        maxLines: 5,
                        minLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Optional image change
                      Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: editedImageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      editedImageBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : (item['image'] != null &&
                                      item['image'].toString().isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item['image'],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.image),
                                    ),
                                  )
                                : const Icon(Icons.image, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    final bytes =
                                        await _pickImageBytesForEdit();
                                    if (bytes != null) {
                                      setDState(() => editedImageBytes = bytes);
                                    }
                                  },
                            icon: const Icon(Icons.photo),
                            label: const Text("Change Image"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty ||
                              descCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Title & Description required'),
                              ),
                            );
                            return;
                          }

                          setDState(() => saving = true);

                          try {
                            String? newUrl;
                            if (editedImageBytes != null) {
                              newUrl = await _uploadEditedImage(
                                editedImageBytes!,
                              );
                            }

                            await _updateNotification(
                              docId: docId,
                              newTitle: titleCtrl.text.trim(),
                              newDesc: descCtrl.text.trim(),
                              newImageUrl: newUrl,
                            );

                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update error: $e')),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setDState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Notifications")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- INPUT FORM ---
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _descController,
                    maxLines: 5,
                    minLines: 3,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _selectedImageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _selectedImageBytes!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.image,
                                size: 50,
                                color: Colors.grey,
                              ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text("Select Image"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _addNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Add Notification'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const Text(
              'Saved Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // --- LIST VIEW (Read Data) ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text("Something went wrong");
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.requireData;

                  return ListView.builder(
                    itemCount: data.size,
                    itemBuilder: (context, index) {
                      final doc = data.docs[index];
                      final item = doc.data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading:
                              (item['image'] != null &&
                                  item['image'].toString().isNotEmpty)
                              ? Image.network(
                                  item['image'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image),
                                )
                              : const Icon(Icons.notifications),
                          title: Text(item['title'] ?? 'No Title'),
                          subtitle: Text(
                            item['description'] ?? 'No Description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // ✅ EDIT + DELETE buttons
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: "Edit",
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () =>
                                    _openEditDialog(docId: doc.id, item: item),
                              ),
                              IconButton(
                                tooltip: "Delete",
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteNotification(doc.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
