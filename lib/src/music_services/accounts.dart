/// This module contains classes relating to Third Party music services.
library;

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import '../config.dart' as config;
import '../discovery.dart';

final _log = Logger('soco.music_services.accounts');

/// An account for a Music Service.
///
/// Each service may have more than one account: see the Sonos release notes
/// for version 5-2.
class Account {
  /// A unique identifier for the music service to which this account relates,
  /// e.g. '2311' for Spotify.
  String serviceType = '';

  /// A unique identifier for this account
  String serialNumber = '';

  /// The account's nickname
  String nickname = '';

  /// True if this account has been deleted
  bool deleted = false;

  /// The username used for logging into the music service
  String username = '';

  /// Metadata for the account
  String metadata = '';

  /// Used for OpenAuth id for some services
  String oaDeviceId = '';

  /// Used for OpenAuth id for some services
  String key = '';

  /// Static cache of all accounts (weak references in Python, regular map in Dart)
  static final Map<String, Account> _allAccounts = {};

  @override
  String toString() {
    return '<Account \'$serialNumber:$serviceType:$nickname\'>';
  }

  /// Fetch the account data from a Sonos device.
  ///
  /// Parameters:
  ///   - [soco]: a SoCo instance to query. If null, a random device will be used.
  ///
  /// Returns:
  ///   A string containing the account data XML
  static Future<String> _getAccountXml(dynamic soco) async {
    // It is likely that the same information is available over UPnP as well
    // via a call to
    // systemProperties.GetStringX([('VariableName','R_SvcAccounts')]))
    // This returns an encrypted string, and, so far, we cannot decrypt it
    final device = soco ?? await anySoco();
    if (device == null) {
      throw Exception('No Sonos device found');
    }

    _log.fine('Fetching account data from $device');
    final settingsUrl = 'http://${device.ipAddress}:1400/status/accounts';
    final response = await http
        .get(Uri.parse(settingsUrl))
        .timeout(Duration(seconds: (config.requestTimeout ?? 20.0).toInt()));
    _log.fine('Account data: ${response.body}');
    return response.body;
  }

  /// Get all accounts known to the Sonos system.
  ///
  /// Parameters:
  ///   - [soco]: a SoCo instance to query. If null, a random instance is used.
  ///
  /// Returns:
  ///   A map containing account instances. Each key is the account's serial
  ///   number, and each value is the related Account instance. Accounts which
  ///   have been marked as deleted are excluded.
  ///
  /// Note:
  ///   Any existing Account instance will have its attributes updated to those
  ///   currently stored on the Sonos system.
  static Future<Map<String, Account>> getAccounts({dynamic soco}) async {
    final xmlString = await _getAccountXml(soco);
    final root = XmlDocument.parse(xmlString).rootElement;

    // _getAccountXml returns an XML structure like this:
    //
    // <ZPSupportInfo type="User">
    //   <Accounts LastUpdateDevice="RINCON_000XXXXXXXX400"
    //             Version="8" NextSerialNum="5">
    //     <Account Type="2311" SerialNum="1">
    //         <UN>12345678</UN>
    //         <MD>1</MD>
    //         <NN></NN>
    //         <OADevID></OADevID>
    //         <Key></Key>
    //     </Account>
    //     <Account Type="41735" SerialNum="3" Deleted="1">
    //         <UN></UN>
    //         <MD>1</MD>
    //         <NN>Nickname</NN>
    //         <OADevID></OADevID>
    //         <Key></Key>
    //     </Account>
    //   </Accounts>
    // </ZPSupportInfo>

    final xmlAccounts = root.findAllElements('Account');
    final result = <String, Account>{};

    for (final xmlAccount in xmlAccounts) {
      final serialNumber = xmlAccount.getAttribute('SerialNum') ?? '';
      final isDeleted = xmlAccount.getAttribute('Deleted') == '1';

      // _allAccounts is a map keyed by serial number.
      // We use it as a database to store details of the accounts we
      // know about. We need to update it with info obtained from the
      // XML just obtained, so (1) check to see if we already have an
      // entry in _allAccounts for the account we have found in
      // XML; (2) if so, delete it if the XML says it has been deleted;
      // and (3) if not, create an entry for it
      if (_allAccounts.containsKey(serialNumber)) {
        // We have an existing entry in our database. Do we need to
        // delete it?
        if (isDeleted) {
          // Yes, so delete it and move to the next XML account
          _allAccounts.remove(serialNumber);
          continue;
        } else {
          // No, so load up its details, ready to update them
          // (account already exists in _allAccounts)
        }
      } else {
        // We have no existing entry for this account
        if (isDeleted) {
          // but it is marked as deleted, so we don't need one
          continue;
        }
        // If it is not marked as deleted, we need to create an entry
        final account = Account();
        account.serialNumber = serialNumber;
        _allAccounts[serialNumber] = account;
      }

      // Now, update the entry in our database with the details from XML
      final account = _allAccounts[serialNumber]!;
      account.serviceType = xmlAccount.getAttribute('Type') ?? '';
      account.deleted = isDeleted;
      account.username =
          xmlAccount.findElements('UN').firstOrNull?.innerText ?? '';
      // Not sure what 'MD' stands for. Metadata? May Delete?
      account.metadata =
          xmlAccount.findElements('MD').firstOrNull?.innerText ?? '';
      account.nickname =
          xmlAccount.findElements('NN').firstOrNull?.innerText ?? '';
      account.oaDeviceId =
          xmlAccount.findElements('OADevID').firstOrNull?.innerText ?? '';
      account.key = xmlAccount.findElements('Key').firstOrNull?.innerText ?? '';
      result[serialNumber] = account;
    }

    // There is always a TuneIn account, but it is handled separately
    // by Sonos, and does not appear in the xml account data. We
    // need to add it ourselves.
    final tunein = Account();
    tunein.serviceType = '65031'; // Is this always the case?
    tunein.deleted = false;
    tunein.username = '';
    tunein.metadata = '';
    tunein.nickname = '';
    tunein.oaDeviceId = '';
    tunein.key = '';
    tunein.serialNumber = '0';
    result['0'] = tunein;

    return result;
  }

  /// Get a list of accounts for a given music service.
  ///
  /// Parameters:
  ///   - [serviceType]: The service_type to use.
  ///
  /// Returns:
  ///   A list of Account instances.
  static Future<List<Account>> getAccountsForService(String serviceType) async {
    final accounts = await getAccounts();
    return accounts.values.where((a) => a.serviceType == serviceType).toList();
  }
}
