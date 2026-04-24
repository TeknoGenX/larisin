import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role; // 'customer' or 'vendor'
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    final success = await Provider.of<AuthProvider>(context, listen: false)
        .login(_usernameController.text, _passwordController.text);
    
    setState(() => _isLoading = false);
    
    if (success) {
      // Logic after login will be handled by the main app wrapper
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login gagal. Periksa username dan password.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.role == 'customer' ? Colors.blue : Colors.orange;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Haus2 ${widget.role == 'customer' ? 'Customer' : 'Vendor'}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: themeColor),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 25),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: const Text('MASUK'),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegisterScreen(role: widget.role)));
              },
              child: Text('Belum punya akun? Daftar sekarang', style: TextStyle(color: themeColor)),
            ),
          ],
        ),
      ),
    );
  }
}
