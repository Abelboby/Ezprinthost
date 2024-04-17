import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
class MongoDatabase{
  static connect(phoneNumber) async{
    var db =await Db.create("mongodb+srv://abel:abel@cluster0.iqgx2js.mongodb.net/ezprints?retryWrites=true&w=majority&appName=Cluster0");
    await db.open();
    var collection =db.collection(phoneNumber);
    final files = await collection.find().toList();
    final cursor = await collection.find();
    // print(cursor.map((doc) => doc['name'] as String).toList());
    print(await collection.find().toList());
    return files;
  }
  
  

}