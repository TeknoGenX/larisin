import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'shared/auth_provider.dart';
import 'shared/customer_provider.dart';
import 'shared/cart_provider.dart';
import 'shared/login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
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
      theme: ThemeData(primarySwatch: Colors.blue),
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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<CustomerProvider>(context, listen: false)
            .fetchNearbyVendors(auth.token!);
      }
    });

    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<CustomerProvider>(context, listen: false)
          .fetchNearbyVendors(auth.token!);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Pedagang Terdekat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                Provider.of<AuthProvider>(context, listen: false).logout(),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(-6.200000, 106.816666),
              initialZoom: 13.0,
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
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        _showVendorDetails(context, vendor);
                      },
                      child: const Icon(
                        Icons.directions_bike,
                        color: Colors.orange,
                        size: 30,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (customerProvider.isLoading)
            const Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text('Memperbarui lokasi pedagang...',
                        style: TextStyle(fontSize: 12)),
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
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                vendor['username'],
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Pedagang Sedang Berkeliling',
                  style: TextStyle(color: Colors.green)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VendorMenuScreen(vendor: vendor),
                  ));
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white),
                child: const Text('LIHAT MENU & BELI'),
              ),
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
              title: const Text('Beri Ulasan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () =>
                            setDialogState(() => selectedRating = index + 1),
                      );
                    }),
                  ),
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                        hintText: 'Tulis komentar Anda...'),
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
      appBar: AppBar(title: const Text('Riwayat Pesanan')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text(
                        'Order #${order['id']} - Rp ${order['total_price']}'),
                    subtitle: Text(
                        'Status: ${order['status'].toString().toUpperCase()}'),
                    trailing: order['status'] == 'on_delivery'
                        ? ElevatedButton(
                            onPressed: () => _confirmReceipt(order['id']),
                            child: const Text('TERIMA'),
                          )
                        : (order['status'] == 'delivered'
                            ? TextButton.icon(
                                onPressed: () => _showReviewDialog(order['id']),
                                icon:
                                    const Icon(Icons.star, color: Colors.amber),
                                label: const Text('ULAS'),
                              )
                            : null),
                  ),
                );
              },
            ),
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
          title: Text('Menu ${widget.vendor['username']}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'PRODUK'),
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
                          itemCount: _stocks.length,
                          itemBuilder: (context, index) {
                            final item = _stocks[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              child: ListTile(
                                leading:
                                    CircleAvatar(child: Text(item['name'][0])),
                                title: Text(item['name']),
                                subtitle: Text(
                                    'Rp ${item['price']} - Sisa: ${item['quantity']} Cup'),
                                trailing: ElevatedButton(
                                  onPressed: item['quantity'] > 0
                                      ? () {
                                          cart.addItem(item['product_id'],
                                              item['name'], item['price']);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    '${item['name']} ditambah ke keranjang'),
                                                duration:
                                                    const Duration(seconds: 1)),
                                          );
                                        }
                                      : null,
                                  child: const Text('TAMBAH'),
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
                          itemCount: _reviews.length,
                          itemBuilder: (context, index) {
                            final review = _reviews[index];
                            return ListTile(
                              leading:
                                  CircleAvatar(child: const Icon(Icons.person)),
                              title: Row(
                                children: List.generate(
                                    5,
                                    (i) => Icon(
                                          Icons.star,
                                          size: 14,
                                          color: i < review['rating']
                                              ? Colors.amber
                                              : Colors.grey,
                                        )),
                              ),
                              subtitle:
                                  Text(review['comment'] ?? 'Tanpa komentar'),
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
                label: Text('Keranjang (${cart.itemCount})'),
                icon: const Icon(Icons.shopping_cart),
                backgroundColor: Colors.green,
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
    setState(() => _isOrdering = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pesanan Berhasil! Menunggu Konfirmasi Pedagang.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pemesanan Gagal. Periksa stok atau koneksi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final item = cart.items.values.toList()[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.quantity} x Rp ${item.price}'),
                  trailing: Text('Rp ${item.quantity * item.price}'),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 7,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pembayaran:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Rp ${cart.totalAmount}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 20),
                _isOrdering
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: cart.itemCount > 0 ? _processOrder : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('BELI SEKARANG'),
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
