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
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return Product.fromJson(data);
            }).toList());
  }

  Future<void> addProduct(Product product) async {
    await _db.collection(collection).doc(product.id).set(product.toJson());
  }

  Future<void> updateProduct(Product product) async {
    await _db.collection(collection).doc(product.id).update(product.toJson());
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection(collection).doc(id).delete();
  }

  Future<void> updateReturnStatus(String id, ReturnStatus status, {String? reason}) async {
    await _db.collection(collection).doc(id).update({
      'returnStatus': status.index,
      if (reason != null) 'returnReason': reason,
      'returnDate': DateTime.now().toIso8601String(),
    });
  }
}