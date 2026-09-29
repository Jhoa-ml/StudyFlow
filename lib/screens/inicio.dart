import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/usuario.dart';
import '../models/tarea.dart';

class InicioScreen extends StatefulWidget {
  final Usuario usuario;

  const InicioScreen({super.key, required this.usuario});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  List<Tarea> tareas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarTareas();
  }

  Future<void> cargarTareas() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        throw Exception('No hay una sesión de Firebase activa.');
      }

      final resultado = await FirebaseFirestore.instance
          .collection('tareas')
          .where('usuarioId', isEqualTo: uid)
          .orderBy('fecha')
          .get();

      final tareasFirebase = resultado.docs.map((doc) {
        final data = doc.data();

        return Tarea(
          id: data['id'] is int
              ? data['id']
              : int.tryParse(data['id']?.toString() ?? ''),
          titulo: data['titulo']?.toString() ?? '',
          materia: data['materia']?.toString() ?? '',
          fecha: data['fecha']?.toString() ?? '',
          prioridad: data['prioridad']?.toString() ?? 'Media',
          completada: data['completada'] == true || data['completada'] == 1,
          usuarioId: null,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        tareas = tareasFirebase;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar las tareas: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = tareas.where((tarea) => !tarea.completada).length;

    final completadas = tareas.where((tarea) => tarea.completada).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'StudyFlow',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: cargarTareas,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Hola, ${widget.usuario.nombre} 👋',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Aquí tienes el resumen de tu actividad.',
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),

            const SizedBox(height: 25),

            Row(
              children: [
                Expanded(
                  child: _estadistica(
                    'Pendientes',
                    pendientes.toString(),
                    Icons.pending_actions,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _estadistica(
                    'Completadas',
                    completadas.toString(),
                    Icons.check_circle_outline,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              'Próximas tareas',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (cargando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (tareas.isEmpty)
              _sinTareas()
            else
              ...tareas
                  .take(4)
                  .map(
                    (tarea) => Card(
                      color: const Color(0xFF0B1727),
                      child: ListTile(
                        leading: Icon(
                          tarea.completada
                              ? Icons.check_circle
                              : Icons.assignment_outlined,
                          color: tarea.completada
                              ? Colors.greenAccent
                              : const Color(0xFF35A8FF),
                        ),

                        title: Text(tarea.titulo),

                        subtitle: Text('${tarea.materia} • ${tarea.fecha}'),

                        trailing: Text(
                          tarea.prioridad,
                          style: TextStyle(
                            color: tarea.prioridad == 'Alta'
                                ? Colors.redAccent
                                : Colors.orangeAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _estadistica(String titulo, String valor, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1727),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: const Color(0xFF35A8FF)),

          const SizedBox(height: 12),

          Text(
            valor,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          Text(titulo, style: const TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _sinTareas() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1727),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.task_alt, size: 50, color: Color(0xFF35A8FF)),

          SizedBox(height: 12),

          Text(
            'No tienes tareas todavía',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 5),

          Text(
            'Agrega una tarea desde la sección Tareas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
