import 'package:flutter/material.dart';

import '../models/usuario.dart';
import 'inicio.dart';
import 'tareas.dart';
import 'calendario.dart';
import 'clase.dart';
import 'perfil.dart';

class UserMainScreen extends StatefulWidget {
  final Usuario usuario;

  const UserMainScreen({super.key, required this.usuario});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int indice = 0;

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      InicioScreen(usuario: widget.usuario),
      TareasScreen(usuario: widget.usuario),
      CalendarioScreen(usuario: widget.usuario),
      const ClaseScreen(),
      PerfilScreen(usuario: widget.usuario),
    ];

    return Scaffold(
      body: pantallas[indice],
      bottomNavigationBar: NavigationBar(
        selectedIndex: indice,
        onDestinationSelected: (index) {
          setState(() {
            indice = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_outlined),
            selectedIcon: Icon(Icons.task),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Clase',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
