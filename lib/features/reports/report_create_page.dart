import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  // Variables para la imagen
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

  // ✅ Menú para elegir entre Cámara y Galería
  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFF667EEA),
              ),
              title: const Text(
                'Tomar foto con la cámara',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context); // Cierra el menú
                _pickImage(ImageSource.camera); // Llama a la cámara
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF667EEA),
              ),
              title: const Text(
                'Elegir de la galería',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context); // Cierra el menú
                _pickImage(ImageSource.gallery); // Llama a la galería
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Recibe de dónde viene la imagen (Cámara o Galería)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      setState(
        () => error = "Error al abrir la cámara/galería. Revisa los permisos.",
      );
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
      // ✅ Enviamos todo al backend (incluida la imagen como archivo)
      // El backend se encarga de subir la imagen a Firebase Storage de forma segura
      final submission = await _service.createReport(
        title: title,
        description: desc,
        imageFile: _imageFile, // ✅ Enviamos el archivo directamente
      );

      if (!mounted) return;
      final confirmation = submission.warnings.isEmpty
          ? "Reporte enviado correctamente."
          : "Reporte enviado. ${submission.warnings.join(' ')}";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(confirmation)));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = ReportService.userMessageForError(e));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Nuevo Reporte",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFFF4F6F9),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Card(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Título de la alerta",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        hintText: "Ej: Sospechoso / Ruido / Emergencia",
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF667EEA),
                            width: 2,
                          ),
                        ),
                      ),
                      maxLength: 100,
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      "Descripción detallada",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descCtrl,
                      decoration: InputDecoration(
                        hintText: "Describe lo ocurrido detalladamente...",
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF667EEA),
                            width: 2,
                          ),
                        ),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "Evidencia fotográfica (Opcional)",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      // ✅ LLAMAMOS AL MENÚ PARA ELEGIR CÁMARA O GALERÍA
                      onTap: loading ? null : _showImageSourceActionSheet,
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.file(
                                  _imageFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 50,
                                    color: Color(0xFF999999),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    "Toca para tomar o subir una foto",
                                    style: TextStyle(
                                      color: Color(0xFF777777),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_imageFile != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: loading
                              ? null
                              : () => setState(() => _imageFile = null),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            "Quitar foto",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  "Enviar Reporte",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
