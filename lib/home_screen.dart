import 'package:flutter/material.dart';
import 'seeder_map_simulation.dart';
import 'seeder_2d_simulation.dart'; 
import 'seeder_3d_simulation.dart'; 

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Демо Сівалки'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Seeder2dSimulation(),
                    ),
                  );
                },
                icon: const Icon(Icons.grid_on),
                label: const Text('Почати 2D Демо'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Seeder3dSimulation(),
                    ),
                  );
                },
                icon: const Icon(Icons.view_in_ar),
                label: const Text('Почати 3D Демо'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SeederMapSimulation()),
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text('Почати Демо з Картою'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}