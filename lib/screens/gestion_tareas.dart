import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GestionTareasScreen extends StatefulWidget {
  final String usuarioUid;

  const GestionTareasScreen({super.key, required this.usuarioUid});

  @override
  State<GestionTareasScreen> createState() => _GestionTareasScreenState();
}

class _GestionTareasScreenState extends State<GestionTareasScreen> {
  final _tituloController = TextEditingController();
  final _materiaController = TextEditingController();
  final _fechaController = TextEditingController();
  String _prioridad = 'Media';
  bool _guardando = false;

  Future<void> _guardarTarea() async {
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor escribe un título')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await FirebaseFirestore.instance.collection('tareas').add({
        'usuarioId': widget.usuarioUid,
        'titulo': _tituloController.text.trim(),
        'materia': _materiaController.text.trim(),
        'fechaEntrega': _fechaController.text.trim(),
        'prioridad': _prioridad,
        'completada': false,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Regresar tras guardar
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar la tarea')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Tarea'),
        backgroundColor: const Color(0xFF1B365D),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título de la tarea',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _materiaController,
              decoration: const InputDecoration(labelText: 'Materia'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fechaController,
              decoration: const InputDecoration(labelText: 'Fecha de entrega'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _prioridad,
              decoration: const InputDecoration(labelText: 'Prioridad'),
              items: [
                'Baja',
                'Media',
                'Alta',
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _prioridad = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardarTarea,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF35A8FF),
                ),
                child: _guardando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar Tarea'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
