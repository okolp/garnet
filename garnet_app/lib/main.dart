import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/home_screen.dart';
import 'auth/auth_service.dart';
import 'screens/register_page.dart'; // add at top


void main() {
  runApp(const GarnetApp());
}

class GarnetApp extends StatelessWidget {
  const GarnetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garnet Recipes',
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      initialRoute: '/',
      routes: {
        '/': (context) => const RootPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomeScreen(),
        '/register': (context) => const RegisterPage(), // add this

      },
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService.getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Token exists
          Future.microtask(() => Navigator.pushReplacementNamed(context, '/home'));
        } else {
          // No token
          Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
        }

        return const SizedBox.shrink(); // Invisible placeholder
      },
    );
  }
}
