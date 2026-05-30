import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shared/auth_provider.dart';
import 'shared/product_provider.dart';
import 'shared/location_provider.dart';
import 'shared/vendor_order_provider.dart';
import 'shared/login_screen.dart';
import 'shared/app_theme.dart';
import 'shared/socket_service.dart';
import 'shared/chat_provider.dart';
import 'shared/chat_screen.dart';
import 'shared/chat_list_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => VendorOrderProvider()),
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
  @override
  void initState() {
    super.initState();
    _initSocketAndTracking();
  }

  void _initSocketAndTracking() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user?['is_verified'] == true && auth.token != null) {
        // Start Location Tracking (already handles its own timer)
        Provider.of<LocationProvider>(context, listen: false)
            .startTracking(auth.token!);
        
        // Fetch Initial Orders
        Provider.of<VendorOrderProvider>(context, listen: false)
            .fetchOrders(auth.token!);
        Provider.of<ChatProvider>(context, listen: false)
            .fetchConversations(auth.token!);
            
        // Connect Socket
        final socketService = Provider.of<SocketService>(context, listen: false);
        socketService.connect(auth.user!['id']);
        
        // Listen for new orders
        socketService.on('new_order', (data) {
          if (mounted) {
            Provider.of<VendorOrderProvider>(context, listen: false)
                .handleNewOrder(Map<String, dynamic>.from(data), auth.token!);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PESANAN BARU MASUK! Dari ${data['customer_name']}'),
                backgroundColor: AppTheme.brandAccent,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });

        // Listen for incoming chat messages
        socketService.on('new_chat_message', (data) {
          if (mounted) {
            Provider.of<ChatProvider>(context, listen: false)
                .handleIncomingMessage(Map<String, dynamic>.from(data), token: auth.token);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pesan dari ${data['sender_name']}: ${data['message']}'),
                action: SnackBarAction(
                  label: 'BALAS',
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: data['sender_id'],
                        receiverName: data['sender_name'],
                      ),
                    ));
                  },
                ),
              ),
            );
          }
        });

        // Listen for typing status
        socketService.on('typing_status', (data) {
          if (mounted) {
            Provider.of<ChatProvider>(context, listen: false)
                .setTypingStatus(data['sender_id'], data['is_typing']);
          }
        });

        // Listen for messages read status
        socketService.on('messages_read', (data) {
          if (mounted) {
            Provider.of<ChatProvider>(context, listen: false)
                .handleMessagesRead(data['reader_id']);
          }
        });

        // Listen for catalog updates (new products added by admin)
        socketService.on('catalog_updated', (data) {
          if (mounted) {
            Provider.of<ProductProvider>(context, listen: false)
                .fetchProducts(auth.token!);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Produk baru tersedia: ${data['product']['name']}'),
                backgroundColor: AppTheme.brandPrimary,
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
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
        title: const Text('Vendor Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.logout, color: Colors.white, size: 20),
            ),
            onPressed: () {
              Provider.of<LocationProvider>(context, listen: false)
                  .stopTracking();
              Provider.of<SocketService>(context, listen: false).disconnect();
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.brandPrimary.withValues(alpha: 0.1),
                  child: Text(user?['username'][0].toUpperCase() ?? 'V', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.brandPrimary)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Halo, ${user?['username']}!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      Text(user?['is_verified'] == true ? 'Verified Merchant' : 'Awaiting Verification', style: TextStyle(color: user?['is_verified'] == true ? AppTheme.brandAccent : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (user?['is_verified'] == false)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 16),
                    Expanded(child: Text('Akun Anda sedang dalam proses verifikasi oleh Admin. Fitur jualan akan aktif segera.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                ),
              )
            else ...[
               Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.brandPrimary, Color(0xFF6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppTheme.brandPrimary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Column(
                  children: [
                    const Text('PESANAN PERLU DIPROSES', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('$pendingOrders', style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VendorOrderScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.brandPrimary,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('BUKA DAFTAR PESANAN'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Update Stok',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockUpdateScreen())),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Consumer<ChatProvider>(
                      builder: (context, chat, _) {
                        return Stack(
                          children: [
                            _buildActionCard(
                              icon: Icons.chat_bubble_outline,
                              label: 'Pesan',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen())),
                            ),
                            if (chat.totalUnreadCount > 0)
                              Positioned(
                                right: 12,
                                top: 12,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  child: Text(
                                    '${chat.totalUnreadCount}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: AppTheme.brandAccent),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Pelacakan GPS Aktif. Pastikan Anda tetap berada di rute jualan.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.brandPrimary, size: 32),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
      appBar: AppBar(title: const Text('Daftar Pesanan', style: TextStyle(fontWeight: FontWeight.bold))),
      body: orderProvider.isLoading && orderProvider.orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (auth.token != null) {
                  await orderProvider.fetchOrders(auth.token!);
                }
              },
              child: orderProvider.orders.isEmpty
                ? ListView(children: const [SizedBox(height: 100), Center(child: Text('Belum ada pesanan masuk.'))])
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: orderProvider.orders.length,
                    itemBuilder: (context, index) {
                      final order = orderProvider.orders[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          title: Text('Order #${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Total: Rp ${order['total_price']} • ${_formatStatus(order['status'])}'),
                          children: [
                            const Divider(),
                            ...order['items'].map<Widget>((item) => ListTile(
                              leading: const Icon(Icons.local_drink_outlined, size: 20),
                              title: Text(item['product_name'] ?? 'Produk ID: ${item['product_id']}', style: const TextStyle(fontSize: 14)),
                              trailing: Text('${item['quantity']} Cup', style: const TextStyle(fontWeight: FontWeight.bold)),
                            )).toList(),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _buildActionButtons(context, order, orderProvider, auth.token!),
                            )
                          ],
                        ),
                      );
                    },
                  ),
            ),
    );
  }

  String _formatStatus(String status) => status.toUpperCase();

  Widget _buildActionButtons(BuildContext context, dynamic order, VendorOrderProvider provider, String token) {
    if (order['status'] == 'paid') {
      return ElevatedButton(
        onPressed: () => provider.updateStatus(token, order['id'], 'processing'),
        child: const Text('PROSES PESANAN'),
      );
    } else if (order['status'] == 'processing') {
      return ElevatedButton(
        onPressed: () => provider.updateStatus(token, order['id'], 'on_delivery'),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandAccent),
        child: const Text('MULAI KIRIM'),
      );
    } else if (order['status'] == 'on_delivery') {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, color: Colors.orange),
          SizedBox(width: 8),
          Text('Pesanan sedang dikirim...', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ],
      );
    } else {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppTheme.brandAccent),
          SizedBox(width: 8),
          Text('Pesanan Selesai', style: TextStyle(color: AppTheme.brandAccent, fontWeight: FontWeight.bold)),
        ],
      );
    }
  }
}

class StockUpdateScreen extends StatefulWidget {
  const StockUpdateScreen({super.key});

  @override
  State<StockUpdateScreen> createState() => _StockUpdateScreenState();
}

class _StockUpdateScreenState extends State<StockUpdateScreen> {
  final Map<int, int> _stockInputs = {};
  final Map<int, TextEditingController> _controllers = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<ProductProvider>(context, listen: false).fetchProducts(auth.token!).then((_) {
        // Initialize inputs with current stock
        if (mounted) {
          final products = Provider.of<ProductProvider>(context, listen: false).products;
          setState(() {
            for (var p in products) {
              int qty = p['current_stock'] ?? 0;
              _stockInputs[p['id']] = qty;
              _controllers[p['id']] = TextEditingController(text: qty.toString());
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitStock() async {
    setState(() => _isSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    List<Map<String, dynamic>> stockData = _stockInputs.entries
        .map((e) => {'product_id': e.key, 'quantity': e.value})
        .toList();

    final success = await productProvider.updateStock(auth.token!, stockData);
    if (mounted) setState(() => _isSubmitting = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok berhasil diperbarui!')));
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memperbarui stok.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Update Stok Harian', style: TextStyle(fontWeight: FontWeight.bold))),
      body: productProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: productProvider.products.length,
                    itemBuilder: (context, index) {
                      final product = productProvider.products[index];
                      final pid = product['id'] as int;
                      final controller = _controllers[pid];
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Harga Jual: Rp ${product['price']}'),
                          trailing: SizedBox(
                            width: 80,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: '0',
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) {
                                _stockInputs[pid] = int.tryParse(val) ?? 0;
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submitStock,
                          child: const Text('SIMPAN STOK'),
                        ),
                ),
              ],
            ),
    );
  }
}
