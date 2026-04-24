import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  final String role; // 'customer' or 'vendor'
  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ktpController = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    setState(() => _isLoading = true);
    final success = await Provider.of<AuthProvider>(context, listen: false).register(
      _usernameController.text,
      _passwordController.text,
      widget.role,
      ktpImage: widget.role == 'vendor' ? _ktpController.text : null,
    );
    
    setState(() => _isLoading = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi Berhasil. Silahkan Login.')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi Gagal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.role == 'customer' ? Colors.blue : Colors.orange;

    return Scaffold(
      appBar: AppBar(title: Text('Daftar Akun ${widget.role == "customer" ? "Customer" : "Vendor"}'), backgroundColor: themeColor),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
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
              if (widget.role == 'vendor') ...[
                const SizedBox(height: 15),
                TextField(
                  controller: _ktpController,
                  decoration: const InputDecoration(labelText: 'Link Foto KTP', border: OutlineInputBorder(), hintText: 'Contoh: https://image-hosting.com/ktp-anda.jpg'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('Khusus Vendor wajib menyertakan link foto KTP untuk proses verifikasi admin.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
              const SizedBox(height: 25),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                      child: const Text('DAFTAR SEKARANG'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
