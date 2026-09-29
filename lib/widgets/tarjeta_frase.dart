import 'package:flutter/material.dart';
import '../models/frase.dart';
import '../services/frases_service.dart';

class TarjetaFraseMotivacional extends StatefulWidget {
  const TarjetaFraseMotivacional({super.key});

  @override
  State<TarjetaFraseMotivacional> createState() =>
      _TarjetaFraseMotivacionalState();
}

class _TarjetaFraseMotivacionalState extends State<TarjetaFraseMotivacional> {
  late Future<Frase> _futureFrase;

  @override
  void initState() {
    super.initState();
    _futureFrase = FrasesService().obtenerFraseMotivacional();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Frase>(
      future: _futureFrase,
      builder: (context, snapshot) {
        // Mientras carga, mostramos un indicador de progreso muy sutil
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasData) {
          final frase = snapshot.data!;
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            color: const Color(0xFF1B365D), // El azul corporativo que usas
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Inspiración del día',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '"${frase.texto}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '- ${frase.autor}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink(); // Si hay error y falla todo, no muestra nada
      },
    );
  }
}
