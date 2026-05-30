import 'package:flutter/material.dart';

class Product {
  final String name;
  final String price;
  final String parish;
  final String badge;
  final IconData icon;
  final double rating;
  final String seller;

  const Product({
    required this.name,
    required this.price,
    required this.parish,
    required this.badge,
    required this.icon,
    required this.rating,
    required this.seller,
  });
}

const products = [
  Product(name: 'Handmade Jamaican Bracelet', price: 'JMD \$2,500', parish: 'Kingston', badge: 'Made in Jamaica', icon: Icons.watch, rating: 4.8, seller: 'YaadCrafts JA'),
  Product(name: 'Blue Mountain Coffee', price: 'JMD \$4,800', parish: 'St. Andrew', badge: 'Islandwide Delivery', icon: Icons.coffee, rating: 4.9, seller: 'Blue Peak Coffee'),
  Product(name: 'Crochet Beach Bag', price: 'JMD \$6,200', parish: 'St. James', badge: 'Featured Seller', icon: Icons.shopping_bag, rating: 4.9, seller: 'Island Vybz Crochet'),
  Product(name: 'Rasta Bucket Hat', price: 'JMD \$2,800', parish: 'Montego Bay', badge: 'Pickup Nearby', icon: Icons.checkroom, rating: 4.7, seller: 'Island Vybz Crochet'),
  Product(name: 'Jamaican Flag Tote', price: 'JMD \$3,200', parish: 'Portland', badge: 'Made in Jamaica', icon: Icons.shopping_bag_outlined, rating: 4.8, seller: 'Tote Yaad'),
  Product(name: 'Crochet Sun Hat', price: 'JMD \$2,400', parish: 'Manchester', badge: 'Islandwide Delivery', icon: Icons.wb_sunny, rating: 4.9, seller: 'Island Vybz Crochet'),
];

const deliveryOptions = ['Pickup Nearby', 'Knutsford Express', 'Zipmail / Courier', 'Local Bearer Delivery', 'Seller Arranged'];
const paymentOptions = ['Cash on Delivery', 'Bank Transfer', 'Card Payments', 'Lynk', 'NCB', 'Scotia'];
