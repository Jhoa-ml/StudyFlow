import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/usuario.dart';

class MateriasScreen extends StatefulWidget {
  final Usuario usuario;

  const MateriasScreen({super.key, required this.usuario});

  @override
  State<MateriasScreen> createState() => _MateriasScreenState();
}

class _MateriasScreenState extends State<MateriasScreen> {
  final _materiaController = TextEditingController();
  final _profesorController = TextEditingController();

  Future<void> _guardarMateria({DocumentSnapshot? doc}) async {
    final nombre = _materiaController.text.trim();
    final profesor = _profesorController.text.trim();

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre de la materia')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      if (doc == null) {
        // Crear
        await FirebaseFirestore.instance.collection('materias').add({
          'usuarioId': uid,
          'nombre': nombre,
          'profesor': profesor.isEmpty ? 'Sin profesor registrado' : profesor,
          'fechaCreacion': FieldValue.serverTimestamp(),
        });
      } else {
        // Editar
        final String nombreAnterior = doc['nombre'] ?? '';
        await doc.reference.update({
          'nombre': nombre,
          'profesor': profesor.isEmpty ? 'Sin profesor registrado' : profesor,
        });

        // Actualizar el nombre de la materia en las tareas asociadas
        if (nombreAnterior.isNotEmpty && nombreAnterior != nombre) {
          final tareasSnapshot = await FirebaseFirestore.instance
              .collection('tareas')
              .where('usuarioId', isEqualTo: uid)
              .where('materia', isEqualTo: nombreAnterior)
              .get();

          for (var tDoc in tareasSnapshot.docs) {
            await tDoc.reference.update({'materia': nombre});
          }
        }
      }

      _materiaController.clear();
      _profesorController.clear();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            doc == null
                ? 'Materia registrada con éxito'
                : 'Materia actualizada con éxito',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la materia: $e')),
      );
    }
  }

  void _mostrarDialogoMateria({DocumentSnapshot? doc}) {
    if (doc != null) {
      _materiaController.text = doc['nombre'] ?? '';
      _profesorController.text = doc['profesor'] ?? '';
    } else {
      _materiaController.clear();
      _profesorController.clear();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(doc == null ? 'Agregar Materia' : 'Editar Materia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _materiaController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la materia',
                prefixIcon: Icon(Icons.book_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _profesorController,
              decoration: const InputDecoration(
                labelText: 'Profesor (opcional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _guardarMateria(doc: doc),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarMateria(DocumentSnapshot doc) async {
    final String nombreMateria = doc['nombre'] ?? 'esta materia';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar materia'),
        content: Text(
          '¿Estás seguro de eliminar "$nombreMateria"? Se conservarán tus tareas creadas.',
        ),
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
      ).showSnackBar(const SnackBar(content: Text('Materia eliminada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Materias')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoMateria(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Materia'),
        backgroundColor: const Color(0xFF35A8FF),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('materias')
            .where('usuarioId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                      'Aún no has agregado materias',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Toca el botón "+ Nueva Materia" para comenzar a organizar tu ciclo escolar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            );
          }

          final materiasDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materiasDocs.length,
            itemBuilder: (context, index) {
              final doc = materiasDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                color: const Color(0xFF0B1727),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF35A8FF),
                    child: Icon(Icons.book, color: Colors.white),
                  ),
                  title: Text(
                    data['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(data['profesor'] ?? 'Sin profesor'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF35A8FF),
                        ),
                        onPressed: () => _mostrarDialogoMateria(doc: doc),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _eliminarMateria(doc),
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
