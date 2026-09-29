import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/tarea.dart';
import '../models/usuario.dart';

class TareasScreen extends StatefulWidget {
  final Usuario usuario;

  const TareasScreen({super.key, required this.usuario});

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

class _TareasScreenState extends State<TareasScreen> {
  List<Tarea> tareas = [];
  String busqueda = '';
  String filtro = 'Todas';
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
        if (!mounted) return;

        setState(() {
          tareas = [];
          cargando = false;
        });

        return;
      }

      final resultado = await FirebaseFirestore.instance
          .collection('tareas')
          .where('usuarioId', isEqualTo: uid)
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

      tareasFirebase.sort((a, b) {
        return a.fecha.compareTo(b.fecha);
      });

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

  List<Tarea> get tareasFiltradas {
    return tareas.where((tarea) {
      final textoBusqueda = busqueda.toLowerCase();

      final coincideBusqueda =
          tarea.titulo.toLowerCase().contains(textoBusqueda) ||
          tarea.materia.toLowerCase().contains(textoBusqueda);

      final coincideFiltro =
          filtro == 'Todas' ||
          (filtro == 'Pendientes' && !tarea.completada) ||
          (filtro == 'Completadas' && tarea.completada) ||
          tarea.prioridad == filtro;

      return coincideBusqueda && coincideFiltro;
    }).toList();
  }

  Future<void> cambiarEstado(Tarea tarea) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) return;

      final query = await FirebaseFirestore.instance
          .collection('tareas')
          .where('usuarioId', isEqualTo: uid)
          .where('titulo', isEqualTo: tarea.titulo)
          .where('fecha', isEqualTo: tarea.fecha)
          .get();

      if (query.docs.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la tarea.')),
        );

        return;
      }

      final doc = query.docs.first;

      await doc.reference.update({'completada': !tarea.completada});

      await cargarTareas();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar la tarea: $e')),
      );
    }
  }

  Color colorPrioridad(String prioridad) {
    switch (prioridad) {
      case 'Alta':
        return Colors.redAccent;
      case 'Media':
        return Colors.orangeAccent;
      case 'Baja':
        return Colors.greenAccent;
      default:
        return Colors.white54;
    }
  }

  IconData iconoPrioridad(String prioridad) {
    switch (prioridad) {
      case 'Alta':
        return Icons.priority_high;
      case 'Media':
        return Icons.remove;
      case 'Baja':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.circle;
    }
  }

  void mostrarDetalle(Tarea tarea) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1727),
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tarea.titulo,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    color: Color(0xFF35A8FF),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tarea.materia,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF35A8FF),
                  ),
                  const SizedBox(width: 12),
                  Text(tarea.fecha, style: const TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    iconoPrioridad(tarea.prioridad),
                    color: colorPrioridad(tarea.prioridad),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Prioridad: ${tarea.prioridad}',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorPrioridad(tarea.prioridad),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    tarea.completada
                        ? Icons.check_circle
                        : Icons.pending_outlined,
                    color: tarea.completada
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tarea.completada ? 'Completada' : 'Pendiente',
                    style: TextStyle(
                      fontSize: 16,
                      color: tarea.completada
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    cambiarEstado(tarea);
                  },
                  icon: Icon(tarea.completada ? Icons.undo : Icons.check),
                  label: Text(
                    tarea.completada
                        ? 'Marcar como pendiente'
                        : 'Marcar como completada',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = tareasFiltradas;

    final pendientes = tareas.where((tarea) => !tarea.completada).length;

    final completadas = tareas.where((tarea) => tarea.completada).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis tareas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: cargarTareas,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
            child: Row(
              children: [
                Expanded(
                  child: _ResumenCard(
                    icono: Icons.pending_actions,
                    titulo: 'Pendientes',
                    cantidad: pendientes,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResumenCard(
                    icono: Icons.check_circle_outline,
                    titulo: 'Completadas',
                    cantidad: completadas,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  busqueda = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Buscar tarea o materia...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                for (final opcion in [
                  'Todas',
                  'Pendientes',
                  'Completadas',
                  'Alta',
                  'Media',
                  'Baja',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(opcion),
                      selected: filtro == opcion,
                      onSelected: (_) {
                        setState(() {
                          filtro = opcion;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : lista.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 70,
                          color: Colors.white30,
                        ),
                        SizedBox(height: 15),
                        Text(
                          'No hay tareas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Las tareas asignadas aparecerán aquí',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 30),
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      final tarea = lista[index];

                      return Card(
                        color: const Color(0xFF0B1727),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => mostrarDetalle(tarea),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: Checkbox(
                                value: tarea.completada,
                                onChanged: (_) {
                                  cambiarEstado(tarea);
                                },
                              ),
                              title: Text(
                                tarea.titulo,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: tarea.completada
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: tarea.completada
                                      ? Colors.white54
                                      : Colors.white,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${tarea.materia} • ${tarea.fecha}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colorPrioridad(
                                    tarea.prioridad,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tarea.prioridad,
                                  style: TextStyle(
                                    color: colorPrioridad(tarea.prioridad),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final int cantidad;

  const _ResumenCard({
    required this.icono,
    required this.titulo,
    required this.cantidad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1727),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icono, color: const Color(0xFF35A8FF), size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  cantidad.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
