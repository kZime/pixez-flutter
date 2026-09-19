import 'package:pixez/main.dart';
import 'package:pixez/models/account.dart';
import 'package:pixez/network/oauth_client.dart';
import 'package:pixez/network/authorization_failure.dart';

/// Shared by mobile and desktop entry points; navigation belongs to the UI.
Future<void> completeAuthorizationCode(String code) async {
  var stage = AuthorizationStage.exchange;
  try {
    final response = await oAuthClient.code2Token(code);
    stage = AuthorizationStage.account;
    final account = Account.fromJson(response.data).response;
    final user = account.user;
    stage = AuthorizationStage.save;
    final provider = AccountProvider();
    await provider.open();
    await provider.insert(
      AccountPersist(
        userId: user.id,
        userImage: user.profileImageUrls.px170x170,
        accessToken: account.accessToken,
        refreshToken: account.refreshToken,
        deviceToken: '',
        passWord: 'no more',
        name: user.name,
        account: user.account,
        mailAddress: user.mailAddress,
        isPremium: user.isPremium ? 1 : 0,
        xRestrict: user.xRestrict,
        isMailAuthorized: user.isMailAuthorized ? 1 : 0,
      ),
    );
    await accountStore.fetch();
  } catch (error) {
    throw AuthorizationFailure.from(error, stage);
  }
}
