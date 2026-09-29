import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tarea.dart';
import '../models/usuario.dart';

class CalendarioScreen extends StatefulWidget {
  final Usuario usuario;

  const CalendarioScreen({super.key, required this.usuario});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  DateTime fechaSeleccionada = DateTime.now();

  List<Tarea> tareas = [];

  @override
  void initState() {
    super.initState();
    cargarTareas();
  }

  String formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  Future<void> cargarTareas() async {
    try {
      final fecha = formatearFecha(fechaSeleccionada);

      final resultado = await FirebaseFirestore.instance
          .collection('tareas')
          .where('usuarioId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('fecha', isEqualTo: fecha)
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
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar las tareas: $e')));
    }
  }

  Future<void> seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (!mounted) return;

    if (fecha != null) {
      setState(() {
        fechaSeleccionada = fecha;
      });

      await cargarTareas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: seleccionarFecha,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1727),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      size: 50,
                      color: Color(0xFF35A8FF),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formatearFecha(fechaSeleccionada),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Toca para cambiar la fecha',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tareas del día',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: tareas.isEmpty
                  ? const Center(
                      child: Text(
                        'No tienes tareas para este día.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: tareas.length,
                      itemBuilder: (_, index) {
                        final tarea = tareas[index];

                        return Card(
                          color: const Color(0xFF0B1727),
                          child: ListTile(
                            leading: Icon(
                              tarea.completada
                                  ? Icons.check_circle
                                  : Icons.assignment,
                              color: tarea.completada
                                  ? Colors.green
                                  : const Color(0xFF35A8FF),
                            ),
                            title: Text(
                              tarea.titulo,
                              style: TextStyle(
                                decoration: tarea.completada
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            subtitle: Text(tarea.materia),
                            trailing: Text(tarea.prioridad),
                          ),
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
