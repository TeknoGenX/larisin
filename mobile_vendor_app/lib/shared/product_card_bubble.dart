import 'package:flutter/material.dart';
import 'app_theme.dart';

class ProductCardBubble extends StatelessWidget {
  final dynamic product;
  final bool isMe;
  final VoidCallback? onBuyPressed;

  const ProductCardBubble({
    super.key,
    required this.product,
    required this.isMe,
    this.onBuyPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (product == null) return const Text("[Produk tidak tersedia]");

    final int stock = product['stock_quantity'] ?? 0;
    final bool isOutOfStock = stock <= 0;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: ColorFiltered(
                  colorFilter: isOutOfStock 
                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                  child: product['image_url'] != null
                      ? Image.network(
                          product['image_url'],
                          height: 120, width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 120, width: double.infinity,
                          color: AppTheme.brandPrimary.withValues(alpha: 0.1),
                          child: const Icon(Icons.local_drink, color: AppTheme.brandPrimary, size: 48),
                        ),
                ),
              ),
              if (isOutOfStock)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'STOK HABIS',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: isOutOfStock ? Colors.grey : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rp ${product['price']}',
                      style: TextStyle(
                        color: isOutOfStock ? Colors.grey : AppTheme.brandPrimary, 
                        fontWeight: FontWeight.w900, 
                        fontSize: 14
                      ),
                    ),
                    if (!isOutOfStock)
                      Text(
                        'Stok: $stock',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
                if (!isMe && onBuyPressed != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isOutOfStock ? null : onBuyPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOutOfStock ? Colors.grey[300] : AppTheme.brandAccent,
                        foregroundColor: isOutOfStock ? Colors.grey : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: isOutOfStock ? 0 : 2,
                      ),
                      child: Text(
                        isOutOfStock ? 'HABIS' : 'BELI SEKARANG', 
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
