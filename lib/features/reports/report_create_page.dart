import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'report_service.dart';

class ReportCreatePage extends StatefulWidget {
  const ReportCreatePage({super.key});

  @override
  State<ReportCreatePage> createState() => _ReportCreatePageState();
}

class _ReportCreatePageState extends State<ReportCreatePage> {
  final _service = ReportService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // ✅ Variables para la imagen
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ✅ Método para seleccionar imagen de la galería
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Comprimimos un poco para que suba rápido
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // ✅ Método para subir la imagen a Firebase Storage y obtener la URL
  Future<String?> _uploadImageToFirebase() async {
    if (_imageFile == null) return null;

    try {
      // Creamos un nombre único para la imagen basado en la fecha y hora
      final fileName = 'evidencia_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('reports/$fileName');

      // Subimos el archivo
      final uploadTask = await ref.putFile(_imageFile!);

      // Obtenemos el link de descarga público
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception("Error al subir la imagen: $e");
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      setState(() => error = "Completa título y descripción.");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      String? imageUrl;

      // 1. Si hay imagen, la subimos primero a Firebase
      if (_imageFile != null) {
        imageUrl = await _uploadImageToFirebase();
      }

      // 2. Enviamos todo a nuestro backend Node.js
      await _service.createReport(
        title: title,
        description: desc,
        imageUrl: imageUrl, // ✅ Enviamos la URL si existe
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reporte enviado ✅")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo reporte")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView( // ✅ Añadido para que no marque error de espacio si el teclado se abre
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: "Título",
                  hintText: "Ej: Robo / Sospechoso / Ruido / Emergencia",
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: "Descripción",
                  hintText: "Describe lo ocurrido…",
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 20),

              // ✅ Botón y vista previa de la imagen
              Text("Evidencia fotográfica (Opcional):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: loading ? null : _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_imageFile!, fit: BoxFit.cover),
                  )
                      : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("Toca para añadir foto", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              if (_imageFile != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: loading ? null : () => setState(() => _imageFile = null),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text("Quitar foto", style: TextStyle(color: Colors.red))
                  ),
                ),

              const SizedBox(height: 16),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : _submit,
                  child: Text(loading ? "Subiendo reporte y foto..." : "Enviar reporte"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}