import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/usuario.dart';
import 'login.dart';

class PerfilScreen extends StatefulWidget {
  final Usuario usuario;

  const PerfilScreen({super.key, required this.usuario});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  int tareasTotales = 0;
  int tareasPendientes = 0;
  int tareasCompletadas = 0;

  bool notificaciones = true;
  String inicioSemana = 'Lunes';

  @override
  void initState() {
    super.initState();
    cargarEstadisticas();
  }

  Future<void> cargarEstadisticas() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        if (!mounted) return;

        setState(() {
          tareasTotales = 0;
          tareasCompletadas = 0;
          tareasPendientes = 0;
        });

        return;
      }

      final resultado = await FirebaseFirestore.instance
          .collection('tareas')
          .where('usuarioId', isEqualTo: uid)
          .get();

      int completadas = 0;

      for (final tarea in resultado.docs) {
        final data = tarea.data();

        if (data['completada'] == true || data['completada'] == 1) {
          completadas++;
        }
      }

      if (!mounted) return;

      setState(() {
        tareasTotales = resultado.docs.length;
        tareasCompletadas = completadas;
        tareasPendientes = resultado.docs.length - completadas;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar estadísticas: $e')),
      );
    }
  }

  double get progreso {
    if (tareasTotales == 0) return 0;

    return tareasCompletadas / tareasTotales;
  }

  Future<void> cerrarSesion() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void mostrarCambiarPassword() {
    final nuevaPasswordController = TextEditingController();
    final confirmarPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool cambiando = false;

        return StatefulBuilder(
          builder: (contextDialog, setDialogState) {
            return AlertDialog(
              title: const Text('Cambiar contraseña'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      'Ingresa una nueva contraseña para tu cuenta.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: nuevaPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nueva contraseña',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmarPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: cambiando
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: cambiando
                      ? null
                      : () async {
                          final nueva = nuevaPasswordController.text.trim();
                          final confirmar = confirmarPasswordController.text
                              .trim();

                          if (nueva.isEmpty || confirmar.isEmpty) {
                            ScaffoldMessenger.of(contextDialog).showSnackBar(
                              const SnackBar(
                                content: Text('Completa todos los campos.'),
                              ),
                            );
                            return;
                          }

                          if (nueva.length < 6) {
                            ScaffoldMessenger.of(contextDialog).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'La nueva contraseña debe tener al menos 6 caracteres.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (nueva != confirmar) {
                            ScaffoldMessenger.of(contextDialog).showSnackBar(
                              const SnackBar(
                                content: Text('Las contraseñas no coinciden.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            cambiando = true;
                          });

                          try {
                            final user = FirebaseAuth.instance.currentUser;

                            if (user == null) {
                              throw Exception('No hay una sesión activa.');
                            }

                            await user.updatePassword(nueva);

                            if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext);

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Contraseña actualizada correctamente.',
                                ),
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              cambiando = false;
                            });

                            String mensaje;

                            switch (e.code) {
                              case 'requires-recent-login':
                                mensaje =
                                    'Por seguridad, vuelve a iniciar sesión antes de cambiar la contraseña.';
                                break;
                              case 'weak-password':
                                mensaje = 'La contraseña es demasiado débil.';
                                break;
                              default:
                                mensaje =
                                    e.message ??
                                    'No se pudo actualizar la contraseña.';
                            }

                            ScaffoldMessenger.of(
                              contextDialog,
                            ).showSnackBar(SnackBar(content: Text(mensaje)));
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              cambiando = false;
                            });

                            ScaffoldMessenger.of(contextDialog).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                  child: cambiando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void mostrarInicioSemana() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Inicio de semana'),
          content: RadioGroup<String>(
            groupValue: inicioSemana,
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                inicioSemana = value;
              });

              Navigator.pop(dialogContext);
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(value: 'Lunes', title: Text('Lunes')),
                RadioListTile<String>(value: 'Domingo', title: Text('Domingo')),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: cargarEstadisticas,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: cargarEstadisticas,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),

            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF35A8FF),
                child: Text(
                  usuarioInicial,
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 5),

            Center(
              child: Text(
                widget.usuario.correo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF35A8FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Estudiante',
                  style: TextStyle(
                    color: Color(0xFF35A8FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Resumen académico',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _EstadisticaCard(
                    icono: Icons.assignment_outlined,
                    titulo: 'Totales',
                    valor: tareasTotales,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EstadisticaCard(
                    icono: Icons.pending_actions,
                    titulo: 'Pendientes',
                    valor: tareasPendientes,
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

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1727),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progreso académico',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${(progreso * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFF35A8FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 9,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tareasTotales == 0
                        ? 'Todavía no tienes tareas asignadas.'
                        : '$tareasCompletadas de $tareasTotales tareas completadas',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Información de cuenta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF35A8FF),
                    ),
                    title: const Text('Correo'),
                    subtitle: Text(widget.usuario.correo),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.school_outlined,
                      color: Color(0xFF35A8FF),
                    ),
                    title: const Text('Rol'),
                    subtitle: const Text('Estudiante'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.badge_outlined,
                      color: Color(0xFF35A8FF),
                    ),
                    title: const Text('ID de Firebase'),
                    subtitle: Text(
                      FirebaseAuth.instance.currentUser?.uid ?? 'No disponible',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Preferencias',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              color: const Color(0xFF0B1727),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF35A8FF),
                    ),
                    title: const Text('Notificaciones'),
                    subtitle: Text(
                      notificaciones ? 'Activadas' : 'Desactivadas',
                    ),
                    value: notificaciones,
                    onChanged: (value) {
                      setState(() {
                        notificaciones = value;
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xFF35A8FF),
                    ),
                    title: const Text('Inicio de semana'),
                    subtitle: Text(inicioSemana),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: mostrarInicioSemana,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Cuenta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              color: const Color(0xFF0B1727),
              child: ListTile(
                leading: const Icon(
                  Icons.lock_reset_outlined,
                  color: Color(0xFF35A8FF),
                ),
                title: const Text('Cambiar contraseña'),
                subtitle: const Text('Actualiza la contraseña de tu cuenta'),
                trailing: const Icon(Icons.chevron_right),
                onTap: mostrarCambiarPassword,
              ),
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: cerrarSesion,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String get usuarioInicial {
    final nombre = widget.usuario.nombre.trim();

    if (nombre.isEmpty) {
      return 'U';
    }

    return nombre[0].toUpperCase();
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1727),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icono, color: const Color(0xFF35A8FF), size: 28),
          const SizedBox(height: 8),
          Text(
            valor.toString(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
