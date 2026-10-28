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
  final _profesorController = TextEditingController();
  final _diasController = TextEditingController();

  int _colorIndex = 0;
  final List<Color> _coloresMateria = [
    const Color(0xFF35A8FF), // Azul
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.greenAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
  ];

  Future<void> _agregarMateria() async {
    final materia = _materiaController.text.trim();
    final hora = _horaController.text.trim();
    final aula = _aulaController.text.trim();
    final profesor = _profesorController.text.trim();
    final dias = _diasController.text.trim();

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
        'nombre': materia,
        'hora': hora,
        'aula': aula.isEmpty ? 'Sin aula' : aula,
        'profesor': profesor.isEmpty ? 'Por asignar' : profesor,
        'dias': dias.isEmpty ? 'Lunes a Viernes' : dias,
        'colorIndex': _colorIndex,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      _materiaController.clear();
      _horaController.clear();
      _aulaController.clear();
      _profesorController.clear();
      _diasController.clear();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materia registrada con éxito')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar materia: $e')));
    }
  }

  void _mostrarDialogoNuevaMateria() {
    _materiaController.clear();
    _horaController.clear();
    _aulaController.clear();
    _profesorController.clear();
    _diasController.clear();
    _colorIndex = 0;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nueva Materia'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _materiaController,
                    decoration: const InputDecoration(
                      labelText: 'Materia / Asignatura',
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
                    controller: _diasController,
                    decoration: const InputDecoration(
                      labelText: 'Días (ej. Lun - Mié - Vie)',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _profesorController,
                    decoration: const InputDecoration(
                      labelText: 'Profesor / Docente',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aulaController,
                    decoration: const InputDecoration(
                      labelText: 'Aula / Laboratorio',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Color identificador:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_coloresMateria.length, (index) {
                      final c = _coloresMateria[index];
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            _colorIndex = index;
                          });
                        },
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: c,
                          child: _colorIndex == index
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    }),
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
                onPressed: _agregarMateria,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _eliminarMateria(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final materia = data['materia'] ?? data['nombre'] ?? 'esta materia';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar materia'),
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
      ).showSnackBar(const SnackBar(content: Text('Materia eliminada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Mis materias',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevaMateria,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Materia'),
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
                'Error al cargar materias: ${snapshot.error}',
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
                      'No tienes materias registradas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Presiona el botón "+ Nueva Materia" para agregar tus asignaturas.',
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

              final colorIdx = clase['colorIndex'] is int
                  ? clase['colorIndex'] as int
                  : 0;
              final colorMateria =
                  _coloresMateria[colorIdx % _coloresMateria.length];

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
                          color: colorMateria.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: colorMateria, width: 2),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: colorMateria,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clase['materia'] ??
                                  clase['nombre'] ??
                                  'Sin nombre',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${clase['dias'] ?? 'Lunes a Viernes'} • ${clase['hora'] ?? ''}',
                              style: TextStyle(
                                color: colorMateria,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Prof: ${clase['profesor'] ?? 'Por asignar'} | Aula: ${clase['aula'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
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
