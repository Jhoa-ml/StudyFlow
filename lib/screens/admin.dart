import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/usuario.dart';
import 'login.dart';

class AdminScreen extends StatefulWidget {
  final Usuario usuario;

  const AdminScreen({super.key, required this.usuario});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Panel Administrador',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 28),
            tooltip: 'Mi perfil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminPerfilScreen(usuario: widget.usuario),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Usuarios registrados',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Lista de usuarios en tiempo real desde Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('usuarios')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error al cargar usuarios: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay usuarios registrados',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  final usuariosDocs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: usuariosDocs.length,
                    itemBuilder: (context, index) {
                      final doc = usuariosDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final nombre = data['nombre']?.toString() ?? 'Sin nombre';
                      final correo = data['correo']?.toString() ?? 'Sin correo';
                      final rol = data['rol']?.toString() ?? 'estudiante';

                      return Card(
                        color: const Color(0xFF0B1727),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: rol == 'administrador'
                                ? Colors.amber.withValues(alpha: 0.2)
                                : const Color(
                                    0xFF35A8FF,
                                  ).withValues(alpha: 0.2),
                            child: Icon(
                              rol == 'administrador'
                                  ? Icons.admin_panel_settings
                                  : Icons.person_outline,
                              color: rol == 'administrador'
                                  ? Colors.amber
                                  : const Color(0xFF35A8FF),
                            ),
                          ),
                          title: Text(
                            nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(correo),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: rol == 'administrador'
                                  ? Colors.amber.withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              rol.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: rol == 'administrador'
                                    ? Colors.amber
                                    : const Color(0xFF35A8FF),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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

// ============================================================
// PANTALLA INDEPENDIENTE DE PERFIL DE ADMINISTRADOR
// ============================================================

class AdminPerfilScreen extends StatefulWidget {
  final Usuario usuario;

  const AdminPerfilScreen({super.key, required this.usuario});

  @override
  State<AdminPerfilScreen> createState() => _AdminPerfilScreenState();
}

class _AdminPerfilScreenState extends State<AdminPerfilScreen> {
  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Estás seguro de que deseas salir del panel de administrador?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perfil de Administrador',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 10),

          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF35A8FF),
              child: Text(
                widget.usuario.nombre.isNotEmpty
                    ? widget.usuario.nombre[0].toUpperCase()
                    : 'A',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: Text(
              widget.usuario.nombre,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 5),

          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ADMINISTRADOR',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            'Información de la cuenta',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            color: const Color(0xFF0B1727),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF35A8FF),
                  ),
                  title: const Text('Nombre'),
                  subtitle: Text(widget.usuario.nombre),
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF35A8FF),
                  ),
                  title: const Text('Correo electrónico'),
                  subtitle: Text(widget.usuario.correo),
                ),
                const Divider(height: 1, color: Colors.white10),
                ListTile(
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.amber,
                  ),
                  title: const Text('Rol asignado'),
                  subtitle: Text(widget.usuario.rol.toUpperCase()),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          FilledButton.icon(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}
