import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'shared/auth_provider.dart';
import 'shared/customer_provider.dart';
import 'shared/cart_provider.dart';
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
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const CustomerApp(),
    ),
  );
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haus2 Customer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            return const CustomerHomeScreen();
          }
          return const LoginScreen(role: 'customer');
        },
      ),
    );
  }
}

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initSocketAndData();
  }

  void _initSocketAndData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated && auth.token != null) {
        // Fetch initial data
        Provider.of<CustomerProvider>(context, listen: false)
            .fetchNearbyVendors(auth.token!);
        Provider.of<ChatProvider>(context, listen: false)
            .fetchConversations(auth.token!);
        
        // Connect Socket
        final socketService = Provider.of<SocketService>(context, listen: false);
        socketService.connect(auth.user!['id']);
        
        // Listen for vendor location updates
        socketService.on('vendor_location_update', (data) {
          if (mounted) {
            Provider.of<CustomerProvider>(context, listen: false)
                .updateVendorLocation(Map<String, dynamic>.from(data));
          }
        });

        // Listen for incoming chat messages
        socketService.on('new_chat_message', (data) {
          if (mounted) {
            Provider.of<ChatProvider>(context, listen: false)
                .handleIncomingMessage(Map<String, dynamic>.from(data), token: auth.token);
            
            // Show notification if not already in chat screen with that user
            // For now, just show a simple snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pesan baru dari ${data['sender_name']}'),
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
      }
    });
  }

  @override
  void dispose() {
    // We don't disconnect socket here because it might be needed elsewhere (like chat)
    // But we should stop listening to this specific event if needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Haus2 Discovery', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<ChatProvider>(
            builder: (context, chat, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.chat_outlined, color: Colors.white, size: 20),
                    ),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChatListScreen())),
                  ),
                  if (chat.totalUnreadCount > 0)
                    Positioned(
                      right: 4,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '${chat.totalUnreadCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: AppTheme.brandPrimary,
              child: Icon(Icons.history, color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
          ),
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.logout, color: Colors.white, size: 20),
            ),
            onPressed: () {
                Provider.of<SocketService>(context, listen: false).disconnect();
                Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-6.200000, 106.816666),
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.haus2.app',
              ),
              MarkerLayer(
                markers: customerProvider.nearbyVendors.map((vendor) {
                  return Marker(
                    point: LatLng(
                        vendor['latitude'] ?? 0, vendor['longitude'] ?? 0),
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () => _showVendorDetails(context, vendor),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.brandPrimary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: AppTheme.brandPrimary,
                            size: 40,
                          ),
                          Positioned(
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: Text(
                                vendor['username'],
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          
          // Bottom Info Overlay
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: () {
                    _mapController.move(const LatLng(-6.200000, 106.816666), 14.0);
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: AppTheme.brandPrimary),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.brandPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${customerProvider.nearbyVendors.length} Pedagang Aktif',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Text('Ketuk ikon di peta untuk mulai belanja', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (customerProvider.isLoading)
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Mencari pedagang...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showVendorDetails(BuildContext context, dynamic vendor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.brandPrimary.withValues(alpha: 0.1),
                    child: Text(vendor['username'][0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.brandPrimary)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(vendor['username'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            if (vendor['is_verified'] == true)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified, color: Colors.blue, size: 18),
                              ),
                          ],
                        ),
                        const Text('Pedagang Sedang Berkeliling', style: TextStyle(color: AppTheme.brandAccent, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            receiverId: vendor['id'],
                            receiverName: vendor['username'],
                          ),
                        ));
                      },
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('CHAT'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => VendorMenuScreen(vendor: vendor),
                        ));
                      },
                      child: const Text('LIHAT MENU'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<CustomerProvider>(context, listen: false);
    final data = await provider.fetchOrderHistory(auth.token!);
    setState(() {
      _orders = data;
      _isLoading = false;
    });
  }

  void _confirmReceipt(int orderId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<CustomerProvider>(context, listen: false);
    final success = await provider.completeOrder(auth.token!, orderId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesanan Selesai! Terima Kasih.')));
      _loadHistory();
    }
  }

  void _showReviewDialog(int orderId) {
    int selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Beri Ulasan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Seberapa puas Anda dengan pelayanan kami?', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () =>
                            setDialogState(() => selectedRating = index + 1),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                        hintText: 'Tulis komentar Anda...',
                        border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('BATAL')),
                ElevatedButton(
                  onPressed: () async {
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
                    final provider =
                        Provider.of<CustomerProvider>(context, listen: false);
                    final success = await provider.submitReview(
                      auth.token!,
                      orderId,
                      selectedRating,
                      commentController.text,
                    );
                    if (success) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Ulasan berhasil dikirim!')));
                    }
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
                  child: const Text('KIRIM'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pesanan', style: TextStyle(fontWeight: FontWeight.bold))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _loadHistory();
              },
              child: _orders.isEmpty 
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [SizedBox(height: 100), Center(child: Text('Belum ada pesanan.'))]
                  )
                : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        shape: const RoundedRectangleBorder(side: BorderSide.none),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order #${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            _buildStatusBadge(order['status']),
                          ],
                        ),
                        subtitle: Text('Total: Rp ${order['total_price']}'),
                        children: [
                          const Divider(),
                          ...order['items'].map<Widget>((item) => ListTile(
                            leading: const Icon(Icons.local_drink_outlined, size: 20),
                            title: Text(item['product_name'] ?? 'Produk ID: ${item['product_id']}', style: const TextStyle(fontSize: 14)),
                            trailing: Text('${item['quantity']} Cup', style: const TextStyle(fontWeight: FontWeight.bold)),
                          )).toList(),
                          if (order['status'] == 'on_delivery' || order['status'] == 'delivered')
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: order['status'] == 'on_delivery'
                                ? ElevatedButton(
                                    onPressed: () => _confirmReceipt(order['id']),
                                    child: const Text('KONFIRMASI TERIMA'),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () => _showReviewDialog(order['id']),
                                    icon: const Icon(Icons.star, color: Colors.amber, size: 18),
                                    label: const Text('BERI ULASAN'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 44),
                                      side: const BorderSide(color: AppTheme.brandPrimary),
                                    ),
                                  ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    switch(status) {
      case 'delivered': color = AppTheme.brandAccent; break;
      case 'on_delivery': color = Colors.orange; break;
      case 'paid': color = Colors.blue; break;
      case 'processing': color = Colors.purple; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

class VendorMenuScreen extends StatefulWidget {
  final dynamic vendor;
  const VendorMenuScreen({super.key, required this.vendor});

  @override
  State<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends State<VendorMenuScreen> {
  List<dynamic> _stocks = [];
  List<dynamic> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<CustomerProvider>(context, listen: false);
    final stockData =
        await provider.fetchVendorStock(auth.token!, widget.vendor['id']);
    final reviewData =
        await provider.fetchVendorReviews(auth.token!, widget.vendor['id']);
    setState(() {
      _stocks = stockData;
      _reviews = reviewData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.vendor['username']),
          bottom: const TabBar(
            indicatorColor: AppTheme.brandPrimary,
            labelColor: AppTheme.brandPrimary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'MENU'),
              Tab(text: 'ULASAN'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Tab Produk
                  _stocks.isEmpty
                      ? const Center(
                          child: Text('Maaf, stok pedagang sedang kosong.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _stocks.length,
                          itemBuilder: (context, index) {
                            final item = _stocks[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(color: AppTheme.brandPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.local_drink, color: AppTheme.brandPrimary),
                                ),
                                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Rp ${item['price']} • Sisa: ${item['quantity']}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle, color: AppTheme.brandPrimary, size: 32),
                                  onPressed: item['quantity'] > 0
                                      ? () {
                                          cart.addItem(item['product_id'],
                                              item['name'], item['price']);
                                          setState(() {
                                            item['quantity'] = item['quantity'] - 1;
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                                content: Text('${item['name']} ditambah ke keranjang'),
                                                duration: const Duration(seconds: 1),
                                                behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                  // Tab Ulasan
                  _reviews.isEmpty
                      ? const Center(
                          child: Text('Belum ada ulasan untuk pedagang ini.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reviews.length,
                          itemBuilder: (context, index) {
                            final review = _reviews[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: List.generate(
                                          5,
                                          (i) => Icon(
                                                Icons.star,
                                                size: 16,
                                                color: i < review['rating']
                                                    ? Colors.amber
                                                    : Colors.grey[300],
                                              )),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(review['comment'] ?? 'Tanpa komentar', style: const TextStyle(fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text('Pembeli Anonim', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
        floatingActionButton: cart.itemCount > 0
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        CheckoutScreen(vendorId: widget.vendor['id']),
                  ));
                },
                label: Text('Check Out (${cart.itemCount})', style: const TextStyle(fontWeight: FontWeight.bold)),
                icon: const Icon(Icons.shopping_cart_checkout),
                backgroundColor: AppTheme.brandAccent,
              )
            : null,
      ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  final int vendorId;
  const CheckoutScreen({super.key, required this.vendorId});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isOrdering = false;

  void _processOrder() async {
    setState(() => _isOrdering = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    final success = await cart.checkout(auth.token!, widget.vendorId);
    if (mounted) setState(() => _isOrdering = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesanan Berhasil! Menunggu Konfirmasi Pedagang.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pemesanan Gagal. Periksa stok atau koneksi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final item = cart.items.values.toList()[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item.quantity} x Rp ${item.price}'),
                    trailing: Text('Rp ${item.quantity * item.price}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pembayaran', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      Text('Rp ${cart.totalAmount}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.brandPrimary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _isOrdering
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: cart.itemCount > 0 ? _processOrder : null,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandAccent),
                          child: const Text('BAYAR SEKARANG'),
                        ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
