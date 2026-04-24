import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shared/auth_provider.dart';
import 'shared/product_provider.dart';
import 'shared/location_provider.dart';
import 'shared/vendor_order_provider.dart';
import 'shared/login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => VendorOrderProvider()),
      ],
      child: const VendorApp(),
    ),
  );
}

class VendorApp extends StatelessWidget {
  const VendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haus2 Vendor',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            return const VendorHomeScreen();
          }
          return const LoginScreen(role: 'vendor');
        },
      ),
    );
  }
}

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  Timer? _orderRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user?['is_verified'] == true) {
        Provider.of<LocationProvider>(context, listen: false)
            .startTracking(auth.token!);
        _startOrderRefresh(auth.token!);
      }
    });
  }

  void _startOrderRefresh(String token) {
    _orderRefreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      Provider.of<VendorOrderProvider>(context, listen: false)
          .fetchOrders(token);
    });
    Provider.of<VendorOrderProvider>(context, listen: false).fetchOrders(token);
  }

  @override
  void dispose() {
    _orderRefreshTimer?.cancel();
    Provider.of<LocationProvider>(context, listen: false).stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final orderProvider = Provider.of<VendorOrderProvider>(context);

    int pendingOrders = orderProvider.orders
        .where((o) => o['status'] == 'paid' || o['status'] == 'processing')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haus2 Vendor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<LocationProvider>(context, listen: false)
                  .stopTracking();
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Selamat Datang, ${user?['username']}!',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (user?['is_verified'] == false)
              const Card(
                color: Colors.redAccent,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Akun Anda sedang menunggu verifikasi admin. Anda belum bisa berjualan.',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else ...[
              const Card(
                color: Colors.green,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.gps_fixed, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Lokasi Anda sedang dipantau secara real-time oleh pembeli.',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const VendorOrderScreen())),
                child: Card(
                  color: Colors.blueAccent,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('PESANAN MASUK',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text('$pendingOrders',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold)),
                        const Text('Perlu Diproses',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: user?['is_verified'] == true
                  ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const StockUpdateScreen()))
                  : null,
              icon: const Icon(Icons.inventory),
              label: const Text('UPDATE STOK HARIAN'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorOrderScreen extends StatelessWidget {
  const VendorOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<VendorOrderProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Pesanan')),
      body: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: orderProvider.orders.length,
              itemBuilder: (context, index) {
                final order = orderProvider.orders[index];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ExpansionTile(
                    title: Text(
                        'Order #${order['id']} - Rp ${order['total_price']}'),
                    subtitle: Text(
                        'Status: ${order['status'].toString().toUpperCase()}'),
                    children: [
                      ...order['items']
                          .map<Widget>((item) => ListTile(
                                title: Text('Produk ID: ${item['product_id']}'),
                                trailing: Text('${item['quantity']} Cup'),
                              ))
                          .toList(),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (order['status'] == 'paid')
                              ElevatedButton(
                                onPressed: () => orderProvider.updateStatus(
                                    auth.token!, order['id'], 'processing'),
                                child: const Text('PROSES'),
                              ),
                            if (order['status'] == 'processing')
                              ElevatedButton(
                                onPressed: () => orderProvider.updateStatus(
                                    auth.token!, order['id'], 'on_delivery'),
                                child: const Text('KIRIM'),
                              ),
                            if (order['status'] == 'on_delivery')
                              const Text('Sedang Dikirim...',
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            if (order['status'] == 'delivered')
                              const Text('Selesai ✅',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// Reuse StockUpdateScreen from previous implementation
class StockUpdateScreen extends StatefulWidget {
  const StockUpdateScreen({super.key});

  @override
  State<StockUpdateScreen> createState() => _StockUpdateScreenState();
}

class _StockUpdateScreenState extends State<StockUpdateScreen> {
  final Map<int, int> _stockInputs = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Provider.of<ProductProvider>(context, listen: false)
        .fetchProducts(auth.token!);
  }

  void _submitStock() async {
    setState(() => _isSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);

    List<Map<String, dynamic>> stockData = _stockInputs.entries
        .map((e) => {'product_id': e.key, 'quantity': e.value})
        .toList();

    final success = await productProvider.updateStock(auth.token!, stockData);
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stok berhasil diperbarui!')));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui stok.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Update Stok Harian')),
      body: productProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: productProvider.products.length,
                    itemBuilder: (context, index) {
                      final product = productProvider.products[index];
                      return ListTile(
                        title: Text(product['name']),
                        subtitle: Text('Harga: Rp ${product['price']}'),
                        trailing: SizedBox(
                          width: 80,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'Qty'),
                            onChanged: (val) {
                              _stockInputs[product['id']] =
                                  int.tryParse(val) ?? 0;
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submitStock,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('SIMPAN STOK'),
                        ),
                ),
              ],
            ),
    );
  }
}
