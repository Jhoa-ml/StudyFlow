import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClaseScreen extends StatefulWidget {
  const ClaseScreen({super.key});

  @override
  State<ClaseScreen> createState() => _ClaseScreenState();
}

class _ClaseScreenState extends State<ClaseScreen> {
  final _materiaController = TextEditingController();
  final _horaController = TextEditingController();
  final _aulaController = TextEditingController();

  Future<void> _agregarClase() async {
    final materia = _materiaController.text.trim();
    final hora = _horaController.text.trim();
    final aula = _aulaController.text.trim();

    if (materia.isEmpty || hora.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa al menos la materia y el horario'),
        ),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('clases').add({
        'usuarioId': uid,
        'materia': materia,
        'hora': hora,
        'aula': aula.isEmpty ? 'Sin aula asignada' : aula,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      _materiaController.clear();
      _horaController.clear();
      _aulaController.clear();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clase registrada con éxito')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar la clase: $e')));
    }
  }

  void _mostrarDialogoNuevaClase() {
    _materiaController.clear();
    _horaController.clear();
    _aulaController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar Clase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _materiaController,
              decoration: const InputDecoration(
                labelText: 'Materia',
                prefixIcon: Icon(Icons.book_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _horaController,
              decoration: const InputDecoration(
                labelText: 'Horario (ej. 08:00 - 10:00)',
                prefixIcon: Icon(Icons.access_time),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aulaController,
              decoration: const InputDecoration(
                labelText: 'Aula / Laboratorio (opcional)',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _agregarClase, child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _eliminarClase(DocumentSnapshot doc) async {
    final materia = doc['materia'] ?? 'esta clase';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar clase'),
        content: Text('¿Deseas eliminar "$materia"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Clase eliminada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis clases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevaClase,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Clase'),
        backgroundColor: const Color(0xFF35A8FF),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clases')
            .where('usuarioId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar clases: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.school_outlined,
                      size: 60,
                      color: Color(0xFF35A8FF),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'No tienes clases registradas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Presiona el botón "+ Nueva Clase" para agregar tu horario escolar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            );
          }

          final clasesDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: clasesDocs.length,
            itemBuilder: (_, index) {
              final doc = clasesDocs[index];
              final clase = doc.data() as Map<String, dynamic>;

              return Card(
                color: const Color(0xFF0B1727),
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF35A8FF,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.class_outlined,
                          color: Color(0xFF35A8FF),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clase['materia'] ?? 'Sin nombre',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              clase['hora'] ?? '',
                              style: const TextStyle(color: Color(0xFF35A8FF)),
                            ),
                            Text(
                              clase['aula'] ?? '',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _eliminarClase(doc),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
