import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../providers/users_providers.dart";
import "message_item.dart";

class Messages extends StatelessWidget {
  const Messages(this.chatId, this.scaffoldKey, {super.key});
  final chatId;
  final scaffoldKey;

  @override
  Widget build(BuildContext context) {
    final UsersProvider usersProvider = Provider.of<UsersProvider>(context);
    return StreamBuilder(
        stream: usersProvider.chatMessages(chatId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.data != null) {
            final doc = snapshot.data!.docs;
            //get the user
            return ListView.builder(
              reverse: true,
              itemCount: doc.length,
              //get is group
              itemBuilder: (ctx, i) => FutureBuilder(
                  future: usersProvider.isGroup(chatId),
                  builder: (context, isGroup) {
                    if (isGroup.hasData &&
                        isGroup.connectionState != ConnectionState.waiting) {
                      final bool isPhoto = doc[i]["type"] == "photo";
                      Future<void> deleteMessage() async {
                        await usersProvider.deleteMessage(
                          doc[i].id,
                          chatId,
                          isPhoto,
                        );
                      }

                      return StreamBuilder(
                          stream: usersProvider.user(doc[i]["userId"]),
                          builder: (context, user) {
                            if (user.hasData &&
                                user.connectionState !=
                                    ConnectionState.waiting) {
                              return MessageItem(
                                doc[i]["${doc[i]["type"]}"],
                                doc[i]["userId"],
                                user.data!["username"],
                                isPhoto,
                                isGroup.data!,
                                i == (doc.length - 1)
                                    ? false
                                    : doc[i + 1]["userId"] == doc[i]["userId"],
                                i == 0
                                    ? false
                                    : doc[(i - 1)]["userId"] ==
                                        doc[i]["userId"],
                                deleteMessage,
                                key: ValueKey(doc[i]),
                              );
                            }
                            return Container();
                          });
                    }
                    return Container();
                  }),
            );
          }
          return Container();
        });
  }
}
