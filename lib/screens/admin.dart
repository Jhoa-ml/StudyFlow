import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/usuario.dart';
import '../firebase_options.dart';
import 'login.dart';

class AdminScreen extends StatefulWidget {
  final Usuario usuario;

  const AdminScreen({super.key, required this.usuario});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Usuario> usuarios = [];
  String busqueda = '';

  int totalTareas = 0;
  int tareasPendientes = 0;
  int tareasCompletadas = 0;
  int totalUsuariosFirebase = 0;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      final usuariosSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .orderBy('nombre')
          .get();

      final tareasSnapshot = await FirebaseFirestore.instance
          .collection('tareas')
          .get();

      final usuariosFirebase = usuariosSnapshot.docs.map((doc) {
        final datos = doc.data();
        return Usuario(
          uid: doc.id,
          nombre: datos['nombre']?.toString() ?? 'Usuario',
          correo: datos['correo']?.toString() ?? '',
          password: '',
          rol: datos['rol']?.toString() ?? 'estudiante',
        );
      }).toList();

      int completadas = 0;
      for (final tarea in tareasSnapshot.docs) {
        final datos = tarea.data();
        final completada = datos['completada'];
        if (completada == true || completada == 1) {
          completadas++;
        }
      }

      if (!mounted) return;

      setState(() {
        usuarios = usuariosFirebase;
        totalUsuariosFirebase = usuariosFirebase.length;
        totalTareas = tareasSnapshot.docs.length;
        tareasCompletadas = completadas;
        tareasPendientes = tareasSnapshot.docs.length - completadas;
      });
    } catch (e) {
      debugPrint('Error al cargar datos de Firebase: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los datos: $e')),
      );
    }
  }

  List<Usuario> get usuariosFiltrados {
    final texto = busqueda.toLowerCase().trim();
    if (texto.isEmpty) return usuarios;

    return usuarios.where((usuario) {
      return usuario.nombre.toLowerCase().contains(texto) ||
          usuario.correo.toLowerCase().contains(texto);
    }).toList();
  }

  int get totalEstudiantes =>
      usuarios.where((usuario) => usuario.rol == 'estudiante').length;

  void abrirPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPerfilScreen(usuario: widget.usuario),
      ),
    );
  }

  Future<void> cerrarSesion() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = usuariosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Consulta Admin'),
        actions: [
          IconButton(
            onPressed: cargarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: abrirPerfil,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF35A8FF),
                child: Text(
                  widget.usuario.nombre.isNotEmpty
                      ? widget.usuario.nombre[0].toUpperCase()
                      : 'A',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: cargarDatos,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Hola, ${widget.usuario.nombre}',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'Métricas del sistema StudyFlow',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 25),

            Row(
              children: [
                Expanded(
                  child: _EstadisticaCard(
                    icono: Icons.groups,
                    titulo: 'Usuarios',
                    valor: totalUsuariosFirebase,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EstadisticaCard(
                    icono: Icons.school_outlined,
                    titulo: 'Estudiantes',
                    valor: totalEstudiantes,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _EstadisticaCard(
                    icono: Icons.assignment_outlined,
                    titulo: 'Total Tareas',
                    valor: totalTareas,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EstadisticaCard(
                    icono: Icons.check_circle_outline,
                    titulo: 'Completadas',
                    valor: tareasCompletadas,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            TextField(
              onChanged: (value) => setState(() => busqueda = value),
              decoration: const InputDecoration(
                hintText: 'Buscar usuario...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Usuarios Registrados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${lista.length}',
                  style: const TextStyle(
                    color: Color(0xFF35A8FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ...lista.map(
              (u) => Card(
                color: const Color(0xFF0B1727),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF35A8FF),
                    child: Text(
                      u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : 'U',
                    ),
                  ),
                  title: Text(u.nombre),
                  subtitle: Text('${u.correo}\n${u.rol}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPerfilScreen extends StatelessWidget {
  final Usuario usuario;

  const AdminPerfilScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil Admin')),
      body: Center(child: Text('Perfil de ${usuario.nombre}')),
    );
  }
}

class _EstadisticaCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final int valor;

  const _EstadisticaCard({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1727),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icono, color: const Color(0xFF35A8FF), size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                valor.toString(),
                style: const TextStyle(
                  fontSize: 22,
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
