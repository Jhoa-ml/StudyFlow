import 'package:flutter/material.dart';

class ClaseScreen extends StatelessWidget {
  const ClaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clases = [
      {
        'materia': 'Desarrollo Móvil',
        'hora': '08:00 - 10:00',
        'aula': 'Laboratorio 2',
        'icono': Icons.phone_android,
      },
      {
        'materia': 'Base de Datos',
        'hora': '10:00 - 12:00',
        'aula': 'Aula 5',
        'icono': Icons.storage,
      },
      {
        'materia': 'Gestión de Proyectos',
        'hora': '12:00 - 14:00',
        'aula': 'Aula 3',
        'icono': Icons.business_center,
      },
      {
        'materia': 'Programación',
        'hora': '14:00 - 16:00',
        'aula': 'Laboratorio 1',
        'icono': Icons.code,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis clases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: clases.length,
        itemBuilder: (_, index) {
          final clase = clases[index];

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
                      color: const Color(0xFF35A8FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      clase['icono'] as IconData,
                      color: const Color(0xFF35A8FF),
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clase['materia'] as String,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          clase['hora'] as String,
                          style: const TextStyle(color: Color(0xFF35A8FF)),
                        ),
                        Text(
                          clase['aula'] as String,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
