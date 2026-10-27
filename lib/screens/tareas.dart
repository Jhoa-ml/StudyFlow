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
  Map<Tarea, String> idsFirestore = {};
  List<String> misMaterias = [];

  String busqueda = '';
  String filtro = 'Todas';
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
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

      // 1. Cargar las materias creadas por este usuario
      final materiasSnap = await FirebaseFirestore.instance
          .collection('materias')
          .where('usuarioId', isEqualTo: uid)
          .get();

      final listaMaterias = materiasSnap.docs
          .map((doc) => doc.data()['nombre']?.toString() ?? '')
          .where((m) => m.isNotEmpty)
          .toList();

      // 2. Cargar las tareas creadas por este usuario
      final tareasSnap = await FirebaseFirestore.instance
          .collection('tareas')
          .where('usuarioId', isEqualTo: uid)
          .get();

      final nuevasTareas = <Tarea>[];
      final nuevosIds = <Tarea, String>{};

      for (final doc in tareasSnap.docs) {
        final data = doc.data();

        String fecha = '';
        final fechaFirebase = data['fecha'];
        if (fechaFirebase is Timestamp) {
          final fDate = fechaFirebase.toDate();
          fecha =
              '${fDate.day.toString().padLeft(2, '0')}/${fDate.month.toString().padLeft(2, '0')}/${fDate.year}';
        } else {
          fecha = fechaFirebase?.toString() ?? '';
        }

        final t = Tarea(
          id: null,
          titulo: data['titulo']?.toString() ?? '',
          materia: data['materia']?.toString() ?? '',
          fecha: fecha,
          prioridad: data['prioridad']?.toString() ?? 'Media',
          completada: data['completada'] == true || data['completada'] == 1,
          usuarioId: uid,
        );

        nuevasTareas.add(t);
        nuevosIds[t] = doc.id;
      }

      if (!mounted) return;

      setState(() {
        tareas = nuevasTareas;
        idsFirestore = nuevosIds;
        misMaterias = listaMaterias;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
    }
  }

  List<Tarea> get tareasFiltradas {
    return tareas.where((tarea) {
      final textoBusqueda = busqueda.toLowerCase().trim();
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
    final docId = idsFirestore[tarea];
    if (docId == null) return;

    try {
      await FirebaseFirestore.instance.collection('tareas').doc(docId).update({
        'completada': !tarea.completada,
      });

      await cargarDatos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al actualizar tarea: $e')));
    }
  }

  Future<void> eliminarTarea(Tarea tarea) async {
    final docId = idsFirestore[tarea];
    if (docId == null) return;

    try {
      await FirebaseFirestore.instance.collection('tareas').doc(docId).delete();
      await cargarDatos();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea eliminada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  void mostrarFormularioTarea({Tarea? tarea}) {
    final tituloController = TextEditingController(text: tarea?.titulo ?? '');
    final materiaController = TextEditingController(text: tarea?.materia ?? '');
    final fechaController = TextEditingController(text: tarea?.fecha ?? '');
    String prioridad = tarea?.prioridad ?? 'Media';
    String? materiaSeleccionada = misMaterias.contains(tarea?.materia)
        ? tarea?.materia
        : null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (contextDialog, setDialogState) {
            return AlertDialog(
              title: Text(tarea == null ? 'Nueva tarea' : 'Editar tarea'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título de la tarea',
                        prefixIcon: Icon(Icons.assignment_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Si hay materias registradas muestra Dropdown, de lo contrario un TextField
                    if (misMaterias.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: materiaSeleccionada,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Materia',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                        items: misMaterias.map((materia) {
                          return DropdownMenuItem(
                            value: materia,
                            child: Text(materia),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            materiaSeleccionada = val;
                            if (val != null) materiaController.text = val;
                          });
                        },
                      ),
                    ] else ...[
                      TextField(
                        controller: materiaController,
                        decoration: const InputDecoration(
                          labelText: 'Materia',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    TextField(
                      controller: fechaController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de entrega',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      onTap: () async {
                        final fecha = await showDatePicker(
                          context: contextDialog,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDate: DateTime.now(),
                        );
                        if (fecha != null) {
                          fechaController.text =
                              '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: prioridad,
                      decoration: const InputDecoration(
                        labelText: 'Prioridad',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Baja', child: Text('Baja')),
                        DropdownMenuItem(value: 'Media', child: Text('Media')),
                        DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            prioridad = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final titulo = tituloController.text.trim();
                    final materia = misMaterias.isNotEmpty
                        ? (materiaSeleccionada ?? '')
                        : materiaController.text.trim();
                    final fecha = fechaController.text.trim();

                    if (titulo.isEmpty || materia.isEmpty || fecha.isEmpty) {
                      ScaffoldMessenger.of(contextDialog).showSnackBar(
                        const SnackBar(
                          content: Text('Completa todos los campos'),
                        ),
                      );
                      return;
                    }

                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;

                    try {
                      final datos = {
                        'titulo': titulo,
                        'materia': materia,
                        'fecha': fecha,
                        'prioridad': prioridad,
                        'usuarioId': uid,
                      };

                      if (tarea == null) {
                        await FirebaseFirestore.instance
                            .collection('tareas')
                            .add({
                              ...datos,
                              'completada': false,
                              'fechaCreacion': FieldValue.serverTimestamp(),
                            });
                      } else {
                        final docId = idsFirestore[tarea];
                        if (docId != null) {
                          await FirebaseFirestore.instance
                              .collection('tareas')
                              .doc(docId)
                              .update(datos);
                        }
                      }

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);

                      await cargarDatos();
                    } catch (e) {
                      ScaffoldMessenger.of(contextDialog).showSnackBar(
                        SnackBar(content: Text('Error al guardar: $e')),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final lista = tareasFiltradas;
    final pendientes = tareas.where((t) => !t.completada).length;
    final completadas = tareas.where((t) => t.completada).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis tareas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: cargarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormularioTarea(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Tarea'),
        backgroundColor: const Color(0xFF35A8FF),
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
              onChanged: (val) => setState(() => busqueda = val),
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
                      onSelected: (_) => setState(() => filtro = opcion),
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
                          Icons.task_outlined,
                          size: 60,
                          color: Colors.white30,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No tienes tareas registradas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Usa el botón "+ Nueva Tarea" para agregar una.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 80),
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      final tarea = lista[index];
                      return Card(
                        color: const Color(0xFF0B1727),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Checkbox(
                            value: tarea.completada,
                            onChanged: (_) => cambiarEstado(tarea),
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
                          subtitle: Text('${tarea.materia} • ${tarea.fecha}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorPrioridad(
                                    tarea.prioridad,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tarea.prioridad,
                                  style: TextStyle(
                                    color: colorPrioridad(tarea.prioridad),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'editar') {
                                    mostrarFormularioTarea(tarea: tarea);
                                  } else if (val == 'eliminar') {
                                    eliminarTarea(tarea);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'editar',
                                    child: Text('Editar'),
                                  ),
                                  PopupMenuItem(
                                    value: 'eliminar',
                                    child: Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ],
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
          Icon(icono, color: const Color(0xFF35A8FF), size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                cantidad.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
