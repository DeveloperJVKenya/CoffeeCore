import 'package:cloud_firestore/cloud_firestore.dart';

class RoleUtils {
  static Future<String> getUserRole(
      String userId, String cooperativeName) async {
    try {
      String formattedCoopName = cooperativeName.replaceAll(' ', '_');

      // Check Main Admin
      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(userId)
          .get();
      if (adminDoc.exists) {
        return 'Main Admin';
      }

      // Check Coop Admin
      DocumentSnapshot coopAdminDoc = await FirebaseFirestore.instance
          .collection('CoopAdmins')
          .doc(userId)
          .get();
      if (coopAdminDoc.exists && coopAdminDoc.data() != null) {
        Map<String, dynamic> data = coopAdminDoc.data() as Map<String, dynamic>;
        if (data['cooperative'] == formattedCoopName) {
          return 'Coop Admin';
        } else {
          throw Exception(
              'User is a Coop Admin for a different cooperative: ${data['cooperative']}');
        }
      }

      // Check Market Manager
      DocumentSnapshot marketManagerDoc = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_marketmanagers')
          .doc(userId)
          .get();
      if (marketManagerDoc.exists) {
        return 'Market Manager';
      }

      // Check Loan Manager
      DocumentSnapshot loanManagerDoc = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_loanmanagers')
          .doc(userId)
          .get();
      if (loanManagerDoc.exists) {
        return 'Loan Manager';
      }

      // Check Coop User
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        return 'User';
      }

      // Validate cooperative existence
      DocumentSnapshot coopDoc = await FirebaseFirestore.instance
          .collection('cooperatives')
          .doc(formattedCoopName)
          .get();
      if (!coopDoc.exists) {
        throw Exception('Cooperative $cooperativeName does not exist');
      }

      return 'None';
    } catch (e) {
      throw Exception('Error checking role: $e');
    }
  }
}
