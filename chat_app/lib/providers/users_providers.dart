import "dart:io";
import "dart:math";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

class UsersProvider with ChangeNotifier {
  String _userId = "";
  int count = 0;
  List _tokenUsers = [];

  String get userId => _userId;

  Future<ThemeMode> get themeMode async {
    final currentUserData = await fuUser(_userId);
    try {
      return currentUserData["themeMode"] == "light"
          ? ThemeMode.dark
          : ThemeMode.light;
    } catch (e) {
      return ThemeMode.light;
    }
  }

  Future<dynamic> isFriend(String id) async {
    bool _isFound = false;
    String? friendsChat;
    final friends =
        await FirebaseFirestore.instance.collection("users").doc(_userId).get();
    for (final friend in friends["friends"]) {
      if (friend["friend"] == id) {
        _isFound = true;
        friendsChat = friend["chat"];
      }
    }
    return _isFound ? friendsChat : _isFound;
  }

  Future<bool> isAdmin(String userId, String groupId) async {
    final GroupData = await FirebaseFirestore.instance
        .collection("/chats")
        .doc(groupId)
        .get();
    final List admins = GroupData["admins"];
    bool isAdmin = false;
    for (var i = 0; i < admins.length; i++) {
      if (userId == admins[i]) {
        isAdmin = true;
      }
    }
    return isAdmin;
  }

  Future<List<bool>> isBlock(String id) async {
    bool _isFound = false;
    bool _isHeFound = false;
    final blocks =
        await FirebaseFirestore.instance.collection("users").doc(_userId).get();
    final heBlocks =
        await FirebaseFirestore.instance.collection("users").doc(id).get();
    if (blocks["blocks"] != null) {
      for (final block in blocks["blocks"]) {
        if (block == id) {
          _isFound = true;
        }
      }
    }
    if (heBlocks["blocks"] != null) {
      for (final block in heBlocks["blocks"]) {
        if (block == _userId) {
          _isHeFound = true;
        }
      }
    }
    return [_isFound, _isHeFound];
  }

  Future<bool> isGroup(chatId) async {
    final chat =
        await FirebaseFirestore.instance.collection("/chats").doc(chatId).get();
    return chat["type"] == "group";
  }

  Future<bool> isUser(String userId) async {
    bool found = false;
    final users = await FirebaseFirestore.instance.collection("/users").get();
    for (final user in users.docs) {
      if (user.id == userId) {
        found = true;
        break;
      }
    }
    return found;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get users =>
      FirebaseFirestore.instance.collection("/users").snapshots();

  Future<QuerySnapshot<Map<String, dynamic>>> get fuUsers =>
      FirebaseFirestore.instance.collection("/users").get();

  Stream<QuerySnapshot<Map<String, dynamic>>> get stChats =>
      FirebaseFirestore.instance
          .collection("/chats")
          .orderBy("lastMessageAt", descending: true)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> chatMessages(String id) =>
      FirebaseFirestore.instance
          .collection("/chats")
          .doc(id)
          .collection("/chat")
          .orderBy("createdAt", descending: true)
          .snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> chat(String id) =>
      FirebaseFirestore.instance.collection("/chats").doc(id).snapshots();

  Future<String> fuUserImage(String id) async {
    final imageData =
        await FirebaseFirestore.instance.collection("/users").doc(id).get();
    final String image = imageData["image_url"];
    return image;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> stUserImage(String id) =>
      FirebaseFirestore.instance.collection("/users").doc(id).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> user(String id) {
    try {
      return FirebaseFirestore.instance
          .collection("/users")
          .doc(id)
          .snapshots();
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fuUser(String id) {
    try {
      return FirebaseFirestore.instance.collection("/users").doc(id).get();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUsername(String username) async {
    await FirebaseFirestore.instance.collection("/users").doc(_userId).update({
      "username": username,
    });
  }

  Future<void> updateUserImage(File imageFIle) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child("users_images")
        .child("${_userId}.jpg");
    late String url;
    await ref.putFile(imageFIle).then((_) async {
      url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection("/users")
          .doc(_userId)
          .update({
        "image_url": url,
      });
    });
  }

  Future<DocumentReference<Map<String, dynamic>>> addChat(String id) async =>
      FirebaseFirestore.instance.collection("/chats").add({
        "lastMessage": "",
        "lastMessageAt": Timestamp.fromDate(DateTime(2022)),
        "type": "private",
        "userId1": userId,
        "userId2": id,
      });

  Future<void> addMessage(String message, String chatId, String type,
      [bool isPhoto = false, String? messageId]) async {
    final String Image = await fuUserImage(userId);
    if (isPhoto) {
      await FirebaseFirestore.instance
          .collection("/chats")
          .doc(chatId)
          .collection("/chat")
          .doc(messageId)
          .set({
        "type": type,
        type: message,
        "createdAt": FieldValue.serverTimestamp(),
        "userId": userId,
        "userImage": Image,
      });
    } else {
      await FirebaseFirestore.instance
          .collection("/chats")
          .doc(chatId)
          .collection("/chat")
          .add({
        "type": type,
        type: message,
        "createdAt": FieldValue.serverTimestamp(),
        "userId": userId,
        "userImage": Image,
      });
    }

    await FirebaseFirestore.instance.collection("/chats").doc(chatId).update({
      "lastMessage": isPhoto ? "photo" : message,
      "lastMessageAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(
      String messageId, String chatId, bool isPhoto) async {
    final messages = await FirebaseFirestore.instance
        .collection("/chats")
        .doc(chatId)
        .collection("chat")
        .orderBy("createdAt", descending: true)
        .get();
    final lastMessages = messages.docs;
    if (lastMessages[0].id == messageId) {
      await FirebaseFirestore.instance.collection("/chats").doc(chatId).update({
        "lastMessage": lastMessages.length == 1
            ? ''
            : lastMessages[1]["type"] == "photo"
                ? "photo"
                : lastMessages[1][lastMessages[1]["type"]],
        "lastMessageAt": lastMessages.length == 1
            ? Timestamp.fromDate(DateTime(2022))
            : lastMessages[1]["createdAt"],
      });
    }
    if (isPhoto) {
      final Reference ref = FirebaseStorage.instance
          .ref()
          .child("users_images")
          .child("$messageId.jpg");
      await ref.delete();
    }
    await FirebaseFirestore.instance
        .collection("/chats")
        .doc(chatId)
        .collection("/chat")
        .doc(messageId)
        .delete();
  }

  Future<void> addMember(String groupId, String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> group = await FirebaseFirestore
        .instance
        .collection("/chats")
        .doc(groupId)
        .get();
    final List members = (group["members"] as List);
    members.add(userId);
    await FirebaseFirestore.instance
        .collection("/chats")
        .doc(groupId)
        .update({"members": members});
  }

  Future<void> removeMember(String memberId, String groupId) async {
    final DocumentSnapshot<Map<String, dynamic>> group = await FirebaseFirestore
        .instance
        .collection("/chats")
        .doc(groupId)
        .get();
    final List members = (group["members"] as List);
    final List admins = (group["admins"] as List);
    final int memberIdx = members.indexOf(memberId);

    if (memberIdx != -1) {
      members.removeAt(memberIdx);
      await FirebaseFirestore.instance
          .collection("/chats")
          .doc(groupId)
          .update({
        "members": members,
      });
    }
    final int adminIdx = admins.indexOf(memberId);
    if (adminIdx != -1) {
      admins.removeAt(adminIdx);
      await FirebaseFirestore.instance
          .collection("/chats")
          .doc(groupId)
          .update({"admins": admins});
    }
    if (members.length == 1) {
      await deleteChat(groupId);
    }
  }

  Future<void> makeAdmin(String memberId, String groupId) async {
    final DocumentSnapshot<Map<String, dynamic>> group = await FirebaseFirestore
        .instance
        .collection("/chats")
        .doc(groupId)
        .get();
    final List admins = (group["admins"] as List);
    admins.add(memberId);
    await FirebaseFirestore.instance
        .collection("/chats")
        .doc(groupId)
        .update({"admins": admins});
  }

  Future<void> deleteChat(String chatId) async {
    await FirebaseFirestore.instance.collection("/chats").doc(chatId).delete();
  }

  Future<void> dismissAdmin(String memberId, String groupId) async {
    final DocumentSnapshot<Map<String, dynamic>> group = await FirebaseFirestore
        .instance
        .collection("/chats")
        .doc(groupId)
        .get();
    final List admins = (group["admins"] as List);
    final int adminIdx = admins.indexOf(memberId);
    if (adminIdx != -1) {
      admins.removeAt(adminIdx);
      await FirebaseFirestore.instance
          .collection("/chats")
          .doc(groupId)
          .update({"admins": admins});
    }
  }

  Future<void> addFriend(String id, String chatId) async {
    final DocumentSnapshot<Map<String, dynamic>> user = await FirebaseFirestore
        .instance
        .collection("/users")
        .doc(_userId)
        .get();
    final List friends = (user["friends"] as List);
    friends.add({"chat": chatId, "friend": id});
    await FirebaseFirestore.instance
        .collection("/users")
        .doc(_userId)
        .update({"friends": friends});

    final DocumentSnapshot<Map<String, dynamic>> user2 =
        await FirebaseFirestore.instance.collection("/users").doc(id).get();
    final List friends2 = (user2["friends"] as List);
    friends2.add({"chat": chatId, "friend": _userId});
    await FirebaseFirestore.instance
        .collection("/users")
        .doc(id)
        .update({"friends": friends2});
  }

  Future<void> setStatus(String status, [String? sign]) async {
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        _userId = FirebaseAuth.instance.currentUser!.uid.trim();
        await FirebaseFirestore.instance
            .collection("users")
            .doc(_userId)
            .update({
          "status": status,
        });
      } catch (e) {}
    }
    if (sign == "out") {
      _userId = "";
    }
  }

  Future<File?> takePicture(
    ImageSource source,
  ) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 150,
    );
    if (photo != null) {
      final File imageFile = File(photo.path);
      return imageFile;
    }
    return null;
  }

  Future<String> sendFile(File file, String fileName) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child("users_images")
        .child("$fileName.jpg");
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    return url;
  }

  List get tokenUsers {
    return _tokenUsers;
  }

  void updateTokenUsers(List newTokenUsers) {
    _tokenUsers = newTokenUsers;
    notifyListeners();
  }

  String generateChatId() {
    const _chars =
        "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890";
    Random _rnd = Random();

    String getRandomString(int length) =>
        String.fromCharCodes(Iterable.generate(
            length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
    return getRandomString(20);
  }

  Future<void> createGroup(
      String chatId, Map<String, dynamic> groupData) async {
    await FirebaseFirestore.instance
        .collection("/chats")
        .doc(chatId)
        .set(groupData);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fuChat(String id) =>
      FirebaseFirestore.instance.collection("/chats").doc(id).get();

  Future<void> blockUser(String userId) async {
    final user = await FirebaseFirestore.instance
        .collection("/users")
        .doc(_userId)
        .get();
    final List userFriends = user["friends"];
    final List userBlocks = user["blocks"];

    int index = -1;
    String chatId = "";

    for (int i = 0; i < userFriends.length; i++) {
      if (userFriends[i]["friend"] == userId) {
        chatId = userFriends[i]["chat"];
        index = i;
      }
    }
    if (index != -1) {
      //remove the user2 friend from current user
      userFriends.removeAt(index);
      userBlocks.add(userId);
      await FirebaseFirestore.instance
          .collection("/users")
          .doc(_userId)
          .update({"friends": userFriends, "blocks": userBlocks});

      //remove the current user friend from user2
      final DocumentSnapshot<Map<String, dynamic>> user2 =
          await FirebaseFirestore.instance
              .collection("/users")
              .doc(userId)
              .get();
      final List friends2 = (user2["friends"] as List);
      for (int i = 0; i < friends2.length; i++) {
        if (friends2[i]["friend"] == _userId) {
          index = i;
        }
      }
      friends2.removeAt(index);
      await FirebaseFirestore.instance.collection("/users").doc(userId).update({
        "friends": friends2,
      });

      await FirebaseFirestore.instance
          .collection("/chats")
          .doc(chatId)
          .delete();
    }
  }

  Future<void> unBlock(String id) async {
    final userData = await FirebaseFirestore.instance
        .collection("/users")
        .doc(_userId)
        .get();
    final List userBlocks = userData['blocks'];
    userBlocks.remove(id);
    await FirebaseFirestore.instance.collection("/users").doc(_userId).update({
      "blocks": userBlocks,
    });
  }

  Future<void> clearMessages(String chatId) async {
    final chatData = FirebaseFirestore.instance
        .collection("/chats")
        .doc(chatId)
        .collection("chat");
    var chat = await chatData.get();
    for (final message in chat.docs) {
      if (message["userId"] == _userId) {
        await chatData.doc(message.id).delete();
      }
    }
    chat = await chatData.get();
    late final String lastMessage;
    late final Timestamp lastMessageAt;
    if (chat.docs.isEmpty) {
      lastMessage = "";
      lastMessageAt = Timestamp.fromDate(DateTime(2022));
    } else {
      final lastMessageData = chat.docs[chat.docs.length - 1];
      lastMessage = lastMessageData[lastMessageData["type"]];
      lastMessageAt = lastMessageData["createdAt"];
    }
    await FirebaseFirestore.instance.collection("/chats").doc(chatId).update({
      "lastMessage": lastMessage,
      "lastMessageAt": lastMessageAt,
    });
  }
}
