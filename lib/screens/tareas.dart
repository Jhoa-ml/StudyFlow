import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tarea.dart';

class TareasScreen extends StatefulWidget {
  final String usuarioUid;

  const TareasScreen({super.key, required this.usuarioUid});

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

class _TareasScreenState extends State<TareasScreen> {
  bool cargando = true;
  String? mensajeError;
  List<Tarea> tareas = [];

  @override
  void initState() {
    super.initState();
    _cargarTareas();
  }

  Future<void> _cargarTareas() async {
    try {
      setState(() {
        cargando = true;
        mensajeError = null;
      });

      // Consulta simple (sin .orderBy) para evitar requerir índices en Firebase
      final snapshot = await FirebaseFirestore.instance
          .collection('tareas')
          .where('usuarioId', isEqualTo: widget.usuarioUid)
          .get();

      final lista = snapshot.docs
          .map((doc) => Tarea.fromMap(doc.data(), doc.id))
          .toList();

      // Ordenar las tareas localmente en Dart por fecha
      lista.sort((a, b) => a.fecha.compareTo(b.fecha));

      setState(() {
        tareas = lista;
        cargando = false;
      });
    } catch (e) {
      setState(() {
        cargando = false;
        mensajeError = 'Error al cargar las tareas.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        backgroundColor: const Color(0xFF1B365D),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : mensajeError != null
          ? Center(
              child: Text(
                mensajeError!,
                style: const TextStyle(color: Colors.white70),
              ),
            )
          : tareas.isEmpty
          ? const Center(
              child: Text(
                'No tienes tareas pendientes.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              itemCount: tareas.length,
              itemBuilder: (context, index) {
                final tarea = tareas[index];
                return Card(
                  color: const Color(0xFF0B1727),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: Icon(
                      tarea.completada
                          ? Icons.check_circle
                          : Icons.assignment_outlined,
                      color: tarea.completada
                          ? Colors.greenAccent
                          : const Color(0xFF35A8FF),
                    ),
                    // Solo se muestran títulos y materias, nunca IDs
                    title: Text(
                      tarea.titulo,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${tarea.materia} • ${tarea.fecha}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Text(
                      tarea.prioridad,
                      style: TextStyle(
                        color: tarea.prioridad == 'Alta'
                            ? Colors.redAccent
                            : Colors.orangeAccent,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
