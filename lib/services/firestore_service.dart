import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final String collection = 'medicine_logs';

  Stream<List<Product>> getProducts() {
    return _db
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Product.fromJson(d.data())).toList());
  }

  Future<void> addProduct(Product product) async {
    await _db.collection(collection).doc(product.id).set(product.toJson());
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection(collection).doc(id).delete();
  }
}