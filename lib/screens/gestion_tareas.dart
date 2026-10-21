import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tarea.dart';
import '../models/usuario.dart';

class GestionTareasScreen extends StatefulWidget {
  const GestionTareasScreen({super.key});

  @override
  State<GestionTareasScreen> createState() => _GestionTareasScreenState();
}

class _GestionTareasScreenState extends State<GestionTareasScreen> {
  List<Tarea> tareas = [];
  List<Usuario> estudiantes = [];

  final Map<String, Usuario> estudiantesPorUid = {};
  final Map<Tarea, String> idsFirestore = {};

  String busqueda = '';
  String filtro = 'Todas';

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  // ============================================================
  // CARGAR TAREAS Y ESTUDIANTES DESDE FIRESTORE
  // ============================================================

  Future<void> cargarDatos() async {
    try {
      final tareasSnapshot = await FirebaseFirestore.instance
          .collection('tareas')
          .orderBy('fecha')
          .get();

      final usuariosSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'estudiante')
          .get();

      final nuevasTareas = <Tarea>[];
      final nuevosIds = <Tarea, String>{};

      for (final documento in tareasSnapshot.docs) {
        final datos = documento.data();

        final tarea = _crearTareaDesdeFirestore(datos);

        nuevasTareas.add(tarea);
        nuevosIds[tarea] = documento.id;
      }

      final nuevosEstudiantes = <Usuario>[];
      final nuevosEstudiantesPorUid = <String, Usuario>{};

      for (final documento in usuariosSnapshot.docs) {
        final datos = documento.data();

        final uid = datos['uid']?.toString() ?? documento.id;

        final estudiante = Usuario(
          uid: uid,
          nombre: datos['nombre']?.toString() ?? 'Estudiante',
          correo: datos['correo']?.toString() ?? '',
          password: '',
          rol: datos['rol']?.toString() ?? 'estudiante',
        );

        nuevosEstudiantes.add(estudiante);
        nuevosEstudiantesPorUid[uid] = estudiante;
      }

      nuevosEstudiantes.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );

      if (!mounted) return;

      setState(() {
        tareas = nuevasTareas;
        estudiantes = nuevosEstudiantes;

        idsFirestore.clear();
        idsFirestore.addAll(nuevosIds);

        estudiantesPorUid.clear();
        estudiantesPorUid.addAll(nuevosEstudiantesPorUid);
      });

      debugPrint('Estudiantes encontrados: ${nuevosEstudiantes.length}');

      for (final estudiante in nuevosEstudiantes) {
        debugPrint('Estudiante: ${estudiante.nombre} | UID: ${estudiante.uid}');
      }
    } catch (e) {
      debugPrint('Error al cargar tareas y estudiantes: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los datos: $e')),
      );
    }
  }

  // ============================================================
  // CONVERTIR FIRESTORE -> TAREA
  // ============================================================

  Tarea _crearTareaDesdeFirestore(Map<String, dynamic> datos) {
    String fecha = '';

    final fechaFirebase = datos['fecha'];

    if (fechaFirebase is Timestamp) {
      final fechaDate = fechaFirebase.toDate();

      fecha =
          '${fechaDate.day.toString().padLeft(2, '0')}/'
          '${fechaDate.month.toString().padLeft(2, '0')}/'
          '${fechaDate.year}';
    } else {
      fecha = fechaFirebase?.toString() ?? '';
    }

    bool completada = false;

    final valorCompletada = datos['completada'];

    if (valorCompletada == true || valorCompletada == 1) {
      completada = true;
    }

    return Tarea(
      id: null,
      titulo: datos['titulo']?.toString() ?? '',
      materia: datos['materia']?.toString() ?? '',
      fecha: fecha,
      prioridad: datos['prioridad']?.toString() ?? 'Media',
      completada: completada,
      usuarioId: datos['usuarioId'] is int
          ? datos['usuarioId']
          : int.tryParse(datos['usuarioId']?.toString() ?? ''),
    );
  }

  // ============================================================
  // FILTRAR TAREAS
  // ============================================================

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

  // ============================================================
  // OBTENER ESTUDIANTE POR UID
  // ============================================================

  Usuario? estudiantePorUid(String? uid) {
    if (uid == null || uid.isEmpty) {
      return null;
    }

    return estudiantesPorUid[uid];
  }

  // ============================================================
  // COLOR DE PRIORIDAD
  // ============================================================

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

  // ============================================================
  // FORMULARIO CREAR / EDITAR TAREA
  // ============================================================

  Future<void> mostrarFormulario({Tarea? tarea}) async {
    final tituloController = TextEditingController(text: tarea?.titulo ?? '');

    final materiaController = TextEditingController(text: tarea?.materia ?? '');

    final fechaController = TextEditingController(text: tarea?.fecha ?? '');

    String prioridad = tarea?.prioridad ?? 'Media';

    String? estudianteUid = tarea?.usuarioId?.toString();

    if (tarea != null && (estudianteUid == null || estudianteUid.isEmpty)) {
      final idDocumento = idsFirestore[tarea];

      if (idDocumento != null) {
        try {
          final documento = await FirebaseFirestore.instance
              .collection('tareas')
              .doc(idDocumento)
              .get();

          if (documento.exists) {
            estudianteUid = documento.data()?['usuarioId']?.toString();
          }
        } catch (e) {
          debugPrint('Error al obtener estudiante de la tarea: $e');
        }
      }
    }

    if (estudianteUid != null &&
        !estudiantesPorUid.containsKey(estudianteUid)) {
      estudianteUid = null;
    }

    if (!mounted) {
      tituloController.dispose();
      materiaController.dispose();
      fechaController.dispose();
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(tarea == null ? 'Nueva tarea' : 'Editar tarea'),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ------------------------------------------------
                    // TÍTULO
                    // ------------------------------------------------

                    TextField(
                      controller: tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        prefixIcon: Icon(Icons.assignment_outlined),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ------------------------------------------------
                    // MATERIA
                    // ------------------------------------------------
                    TextField(
                      controller: materiaController,
                      decoration: const InputDecoration(
                        labelText: 'Materia',
                        prefixIcon: Icon(Icons.menu_book_outlined),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ------------------------------------------------
                    // FECHA
                    // ------------------------------------------------
                    TextField(
                      controller: fechaController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de entrega',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      onTap: () async {
                        final fecha = await showDatePicker(
                          context: dialogContext,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDate: DateTime.now(),
                        );

                        if (fecha != null && dialogContext.mounted) {
                          fechaController.text =
                              '${fecha.day.toString().padLeft(2, '0')}/'
                              '${fecha.month.toString().padLeft(2, '0')}/'
                              '${fecha.year}';
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // ------------------------------------------------
                    // PRIORIDAD
                    // ------------------------------------------------
                    DropdownButtonFormField<String>(
                      initialValue: prioridad,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Prioridad',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Baja', child: Text('Baja')),
                        DropdownMenuItem(value: 'Media', child: Text('Media')),
                        DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            prioridad = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // ------------------------------------------------
                    // ESTUDIANTE
                    // ------------------------------------------------
                    DropdownButtonFormField<String>(
                      initialValue: estudianteUid,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Asignar a estudiante',
                        prefixIcon: const Icon(Icons.person_outline),
                        hintText: estudiantes.isEmpty
                            ? 'No hay estudiantes'
                            : 'Selecciona un estudiante',
                      ),
                      items: estudiantes.map((estudiante) {
                        return DropdownMenuItem<String>(
                          value: estudiante.uid,
                          child: Text(
                            estudiante.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: estudiantes.isEmpty
                          ? null
                          : (value) {
                              setDialogState(() {
                                estudianteUid = value;
                              });
                            },
                    ),

                    if (estudiantes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No se encontraron estudiantes.',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ------------------------------------------------------
              // BOTONES
              // ------------------------------------------------------
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancelar'),
                ),

                FilledButton(
                  onPressed: () async {
                    final titulo = tituloController.text.trim();

                    final materia = materiaController.text.trim();

                    final fecha = fechaController.text.trim();

                    if (titulo.isEmpty ||
                        materia.isEmpty ||
                        fecha.isEmpty ||
                        estudianteUid == null ||
                        estudianteUid!.isEmpty) {
                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Completa todos los campos.'),
                        ),
                      );

                      return;
                    }

                    try {
                      final datos = {
                        'titulo': titulo,
                        'materia': materia,
                        'fecha': fecha,
                        'prioridad': prioridad,
                        'usuarioId': estudianteUid,
                      };

                      // ------------------------------------------------
                      // CREAR
                      // ------------------------------------------------

                      if (tarea == null) {
                        await FirebaseFirestore.instance
                            .collection('tareas')
                            .add({
                              ...datos,
                              'completada': false,
                              'fechaCreacion': FieldValue.serverTimestamp(),
                            });
                      }
                      // ------------------------------------------------
                      // EDITAR
                      // ------------------------------------------------
                      else {
                        final idDocumento = idsFirestore[tarea];

                        if (idDocumento == null) {
                          throw Exception(
                            'No se encontró el documento de la tarea.',
                          );
                        }

                        await FirebaseFirestore.instance
                            .collection('tareas')
                            .doc(idDocumento)
                            .update(datos);
                      }

                      if (!dialogContext.mounted) {
                        return;
                      }

                      Navigator.pop(dialogContext);

                      await cargarDatos();

                      if (!mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tarea == null
                                ? 'Tarea creada correctamente.'
                                : 'Tarea actualizada correctamente.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('No se pudo guardar la tarea: $e'),
                        ),
                      );
                    }
                  },
                  child: Text(tarea == null ? 'Crear tarea' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    tituloController.dispose();
    materiaController.dispose();
    fechaController.dispose();
  }

  // ============================================================
  // ELIMINAR TAREA
  // ============================================================

  Future<void> eliminarTarea(Tarea tarea) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar tarea'),
          content: Text('¿Quieres eliminar "${tarea.titulo}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmar != true) {
      return;
    }

    try {
      final idDocumento = idsFirestore[tarea];

      if (idDocumento == null) {
        throw Exception('No se encontró la tarea.');
      }

      await FirebaseFirestore.instance
          .collection('tareas')
          .doc(idDocumento)
          .delete();

      await cargarDatos();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea eliminada correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la tarea: $e')),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final lista = tareasFiltradas;

    final pendientes = tareas.where((tarea) => !tarea.completada).length;

    final completadas = tareas.where((tarea) => tarea.completada).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de tareas',
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
        onPressed: () => mostrarFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),

      body: Column(
        children: [
          // ========================================================
          // RESUMEN
          // ========================================================

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

                const SizedBox(width: 8),

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

          // ========================================================
          // BUSCADOR
          // ========================================================
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

          // ========================================================
          // FILTROS
          // ========================================================
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

          // ========================================================
          // LISTA DE TAREAS
          // ========================================================
          Expanded(
            child: lista.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
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
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 100),
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      final tarea = lista[index];

                      final estudiante = estudiantePorUid(
                        tarea.usuarioId?.toString(),
                      );

                      return Card(
                        color: const Color(0xFF0B1727),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),

                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF35A8FF),
                            child: Icon(
                              tarea.completada
                                  ? Icons.check
                                  : Icons.assignment_outlined,
                            ),
                          ),

                          title: Text(
                            tarea.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: tarea.completada
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),

                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              '${tarea.materia}\n'
                              '${tarea.fecha}\n'
                              '👤 ${estudiante?.nombre ?? 'Sin asignar'}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          isThreeLine: true,

                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'editar') {
                                mostrarFormulario(tarea: tarea);
                              } else {
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

// ============================================================
// TARJETA DE RESUMEN
// ============================================================

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1727),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: const Color(0xFF35A8FF), size: 26),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
