const Map<String, String> localizedStringsFr = {
  'welcome': 'Bienvenue sur ShareHaven!',
  'version': 'Version',
  'welcoming_description': 'Votre compagnon de portefeuille Bitcoin.',

  // Settings
  'language': 'Sélectionner la langue',
  'currency': 'Sélectionner la devise',
  'settings': 'Paramètres',
  'settings_message':
      'Personnalisez vos paramètres globaux pour une meilleure expérience.',
  'reset_settings': 'Réinitialiser les paramètres',
  'reset_settings_scaffold': 'Paramètres réinitialisés par défaut!',
  'reset_app': 'Réinitialiser l\'application',
  'begin_journey': 'Commencez votre aventure Bitcoin',

  // Network
  'network_banner': 'Réseau Testnet',
  'network': 'Réseau',

  // PIN Setup & Verification
  'enter_pin': 'Entrer le code PIN',
  'enter_6_digits_pin': 'Entrez votre code PIN à 6 chiffres',
  'confirm_pin': 'Confirmer le code PIN',
  'pin_mismatch': 'Le code PIN ne correspond pas',
  'pin_must_be_six': 'Le code PIN doit comporter 6 chiffres',
  'pin_set_success': 'Code PIN défini avec succès!',
  'pin_verified': 'Code PIN vérifié avec succès!',
  'pin_incorrect': 'Code PIN incorrect. Essayez à nouveau.',
  'verify_pin': 'Vérifier le code PIN',
  'success': 'succès',
  'confirm': 'Confirmer',
  're_enter_pin': 'Saisissez à nouveau votre code PIN',

  // Wallet
  'personal_wallet': 'Portefeuille personnel',
  'shared_wallet': 'Portefeuille partagé',
  'ca_wallet': 'Portefeuille CA',
  'pub_key': 'Clé publique',
  'address': 'Adresse',
  'transactions': 'Transactions',
  'wallet_creation': 'Création de portefeuille',
  'backup_your_wallet': 'Sauvegardez votre portefeuille',
  'wallet_backed_up': 'Portefeuille sauvegardé avec succès!',
  'wallet_not_backed_up':
      'Échec de la sauvegarde du portefeuille. Essayez à nouveau.',
  'confirm_wallet_deletion':
      'Êtes-vous sûr de vouloir supprimer ce portefeuille?',
  'current_height': 'Hauteur actuelle du bloc',
  'timestamp': 'Horodatage',
  'multisig_tx': 'Transactions MultiSig',
  'no_transactions_to_sign': 'Aucune transaction à signer',
  'receive_bitcoin': 'Recevoir des Bitcoins',
  'height': 'Hauteur',

  // Transactions & Blockchain
  'fetching_balance': 'Récupération du solde...',
  'balance': 'Solde',
  'pending_balance': 'Solde en attente',
  'confirmed_balance': 'Solde confirmé',
  'transaction_history': 'Historique des transactions',
  'transaction_sent': 'Transaction envoyée',
  'transaction_failed': 'Échec de la transaction',
  'broadcasting_error': 'Erreur de diffusion',
  'transaction_fee': 'Frais de transaction',
  'sending_transaction': 'Envoi de la transaction...',
  'transaction_success': 'Transaction diffusée avec succès!',
  'transaction_failed_retry': 'Échec de la transaction. Veuillez réessayer.',
  'internal': 'Interne',
  'sent': 'Envoyé',
  'received': 'Reçu',
  'to': 'À',
  'from': 'De',
  'fee': 'Frais',
  'amount': 'Montant',
  'transaction_details': 'Détails de la transaction',
  'internal_tx': 'Transaction interne',
  'sent_tx': 'Transaction envoyée',
  'received_tx': 'Transaction reçue',
  'senders': 'Expéditeurs',
  'receivers': 'Destinataires',
  'confirmation_details': 'Détails de confirmation',
  'status': 'Statut',
  'confirmed_block': 'Confirmé au bloc',
  'confirmed': 'Confirmé',
  'mempool': 'Visiter le Mempool',

  // Erreurs et Avertissements
  'error_invalid_address': 'Format d’adresse invalide',
  'error_wallet_creation':
      'Erreur lors de la création du portefeuille avec le descripteur fourni',
  'error_loading_data': 'Erreur lors du chargement des données du portefeuille',
  'error_network': 'Erreur réseau. Veuillez vérifier votre connexion.',
  'error_insufficient_funds':
      'Fonds confirmés insuffisants. Veuillez attendre la confirmation de vos transactions.',
  'error_wallet_locked':
      'Le portefeuille est verrouillé. Veuillez entrer votre code PIN.',
  'error_wallet_not_found': 'Portefeuille introuvable.',
  'invalid_address': 'Adresse invalide',
  'invalid_psbt': 'PSBT invalide',
  'error_older': 'Erreur : Cette valeur Older existe déjà !',
  'invalid_descriptor': 'Veuillez entrer un descripteur valide',
  'invalid_mnemonic': 'Phrase mnémonique invalide. Vérifiez et réessayez.',
  'threshold_missing': 'Seuil manquant',
  'public_keys_missing': 'Clés publiques manquantes',
  'your_public_key_missing': 'Votre clé publique n’est pas incluse',
  'descriptor_name_missing': 'Nom du descripteur manquant',
  'descriptor_name_exists': 'Le nom du descripteur existe déjà',
  'error_validating_descriptor': 'Erreur lors de la validation du descripteur',
  'recipient_address_required': 'Veuillez entrer une adresse de destinataire.',
  'invalid_descriptor_status': 'Descripteur invalide - ',
  'error_wallet_descriptor':
      'Erreur lors de la création du portefeuille avec le descripteur fourni',
  'error_public_key_not_contained':
      'Erreur : Votre clé publique n’est pas contenue dans ce descripteur',
  'spending_path_required': 'Veuillez sélectionner un chemin de dépense',
  'generic_error': 'Erreur',
  'both_fields_required': 'Les deux champs sont obligatoires',
  'pub_key_exists': 'Cette clé publique existe déjà',
  'alias_exists': 'Cet alias existe déjà',
  'correct_errors': 'Veuillez corriger les erreurs et réessayer',

  // Interface d'Envoi/Signature
  'sending_menu': 'Menu d\'Envoi',
  'signing_menu': 'Menu de Signature',
  'recipient_address': 'Adresse du Destinataire',
  'enter_rec_addr': 'Entrez l\'Adresse du Destinataire',
  'psbt': 'PSBT',
  'enter_psbt': 'Entrez PSBT',
  'enter_amount_sats': 'Entrez le Montant (Sats)',
  'keys': 'Clés',
  'blocks': 'Blocs',
  'use_available_balance': 'Utiliser le Solde Disponible',
  'select_spending_path': 'Sélectionner le Chemin de Dépense',
  'psbt_created': 'PSBT Créé',
  'spending_path': 'Chemin de Dépense',
  'signers': 'Signataires',
  'confirm_transaction': 'Voulez-vous signer cette transaction ?',
  'psbt_not_finalized':
      'Ce PSBT n’est pas encore finalisé, partagez-le avec les autres utilisateurs !',

  // File (Fichier)
  'storage_permission_needed':
      'L’autorisation de stockage est requise pour enregistrer le fichier',
  'file_already_exists': 'Le fichier existe déjà',
  'file_save_prompt':
      'Un fichier portant le même nom existe déjà. Voulez-vous l’enregistrer quand même?',
  'file_saved': 'Fichier enregistré dans',
  'file_uploaded': 'Fichier téléchargé avec succès',
  'failed_upload': 'Échec du téléchargement du fichier',

  // Scaffold Messenger (Messages d’alerte)
  'copy_to_clipboard': 'Copier dans le presse-papiers',
  'mnemonic_clipboard': 'Phrase mnémonique copiée dans le presse-papiers',
  'pub_key_clipboard': 'Clé publique copiée dans le presse-papiers',
  'address_clipboard': 'Adresse copiée dans le presse-papiers',
  'descriptor_clipboard': 'Descripteur copié dans le presse-papiers',
  'psbt_clipboard': 'PSBT copié dans le presse-papiers',
  'transaction_created': 'Transaction créée avec succès',
  'transaction_signed': 'Transaction signée avec succès',
  'timelock_condition_removed':
      'Condition de verrouillage temporel ({x}) supprimée',
  'alias_removed': 'supprimé',
  'multisig_updated': 'Multisig mis à jour avec succès',
  'timelock_updated':
      'Condition de verrouillage temporel mise à jour avec succès',
  'alias_updated': 'Alias mis à jour avec succès',
  'sw_info_updated': 'Détails du portefeuille partagé mis à jour avec succès',

  // Private Data (Données Privées)
  'private_data': 'Données privées',
  'saved_mnemonic': 'Voici votre phrase mnémonique enregistrée',
  'saved_descriptor': 'Voici votre descripteur enregistré',
  'saved_pub_key': 'Voici votre clé publique enregistrée',
  'download_descriptor': 'Télécharger le descripteur',
  'wallet_data': 'Données Portefeuille',

  // Buttons (Boutons)
  'close': 'Fermer',
  'save': 'Enregistrer',
  'cancel': 'Annuler',
  'set_pin': 'Définir le PIN',
  'reset': 'Réinitialiser',
  'submit': 'Soumettre',
  'add': 'Ajouter',
  'copy': 'Copier',
  'share': 'Partager',
  'sign': 'Signer',
  'yes': 'Oui',
  'no': 'Non',
  'decode': 'Décode',
  'retry': 'Réessayer 🔄',

  // Spending Summary (Résumé des dépenses)
  'spending_summary': 'Résumé des dépenses',
  'type': 'Type',
  'threshold': 'Seuil',
  'transaction_info': 'Informations sur la transaction',
  'can_be_spent': 'peut être dépensé!',
  'unconfirmed': 'Non confirmé',
  'no_transactions_available': 'Aucune transaction disponible',
  'value': 'Valeur',
  'abs_timelock': 'Verrouillage temporel absolu',
  'rel_timelock': 'Verrouillage temporel relatif',

  // Spending Paths (Chemins de dépenses)
  'immediately_spend': 'Vous ({x}) pouvez immédiatement dépenser avec',
  'cannot_spend': 'Vous ({x}) ne pouvez pas dépenser de sats pour le moment',
  'threshold_required':
      '\nUn seuil de {x} sur {y} est requis. \nVous devez vous coordonner avec ces clés',
  'spend_alone':
      '\nVous pouvez dépenser seul. \nCes autres clés peuvent également dépenser indépendamment: ',
  'spend_together': '\nVous devez dépenser avec: ',
  'total_unconfirmed': 'Total non confirmé: {x} sats',
  'time_remaining_text': 'Temps restant',
  'blocks_remaining': 'Blocs restants',
  'time_remaining': '{x} heures, {y} minutes, {z} secondes',
  'sats_available': 'sats disponibles dans',
  'future_sats': 'les sats seront disponibles à l’avenir',
  'upcoming_funds': 'Fonds à venir - Appuyez sur ⋮ pour plus de détails',
  'spending_paths_available': 'Chemins de dépenses',
  'no_spending_paths_available': 'Aucun chemin de dépenses disponible',

  // Synchronisation
  'no_updates_yet': '⏳ Pas encore de mises à jour ! Réessayez plus tard. 🔄',
  'new_block_transactions_detected':
      '🚀 Nouveau bloc et transactions détectés ! Synchronisation en cours... 🔄',
  'new_block_detected':
      '📦 Nouveau bloc détecté ! Synchronisation en cours... ⛓️',
  'new_transaction_detected':
      '₿ Nouvelle transaction détectée ! Synchronisation en cours... 🔄',
  'no_internet': '🚫 Pas d’Internet ! Connectez-vous et réessayez.',
  'syncing_wallet': '🔄 Synchronisation du portefeuille… Veuillez patienter.',
  'syncing_complete': '✅ Synchronisation terminée !',
  'syncing_error': '⚠️ Oups ! Quelque chose s’est mal passé.\nErreur',

  // Importer Portefeuille
  'import_wallet': 'Importer un Portefeuille Partagé',
  'descriptor': 'Descripteur',
  'generate_public_key': 'Générer une Clé Publique',
  'select_file': 'Sélectionner un Fichier',
  'valid': 'Le descripteur est valide',
  'aliases_and_pubkeys': 'Alias et Clés Publiques',
  'alias': 'Alias',
  'navigating_wallet': 'Navigation vers votre portefeuille',
  'loading': 'Chargement...',
  'idle_ready_import': 'Inactif - Prêt à importer',
  'descriptor_valid_proceed':
      'Le descripteur est valide - Vous pouvez continuer',
  'assistant_scan_qr_descriptor':
      'Appuyez ici pour scanner un QR Code contenant le descripteur à importer !',
  'scan_qr': 'Scanner QR',

  // Créer un Portefeuille Partagé
  'create_shared_wallet': 'Créer un Portefeuille Partagé',
  'descriptor_name': 'Nom du Descripteur',
  'enter_descriptor_name': 'Entrez le Nom du Descripteur',
  'enter_public_keys_multisig': 'Entrez les Clés Publiques pour Multisig',
  'enter_timelock_conditions': 'Entrez les Conditions de Verrouillage Temporel',
  'older': 'Ancien',
  'pub_keys': 'Clés Publiques',
  'create_descriptor': 'Créer un Descripteur',
  'edit_public_key': 'Modifier la Clé Publique',
  'edit_alias': 'Modifier l\'alias',
  'add_public_key': 'Ajouter une Clé Publique',
  'enter_pub_key': 'Entrez la Clé Publique',
  'enter_alias': 'Entrez le Nom de l\'Alias',
  'edit_timelock': 'Modifier la Condition de Verrouillage Temporel',
  'add_timelock': 'Ajouter une Condition de Verrouillage Temporel',
  'enter_older': 'Entrez la Valeur Ancienne',
  'descriptor_created': 'Descripteur {x} Créé',
  'conditions': 'Conditions',
  'aliases': 'Alias',
  'edit_sw_info': 'Modifier les détails du portefeuille partagé',
  'enter_after': 'Entrez la condition After',
  'after': 'Après',

  // Créer ou Restaurer un Portefeuille Unique
  'create_restore': 'Créer ou Restaurer un Portefeuille',
  'new_mnemonic': 'Nouveau mnémonique généré !',
  'wallet_loaded': 'Portefeuille chargé avec succès !',
  'wallet_created': 'Portefeuille créé avec succès !',
  'creating_wallet': 'Création du portefeuille en cours...',
  'enter_mnemonic': 'Entrez le Mnémonique',
  'enter_12': 'Entrez ici votre mnémonique de 12 mots',
  'create_wallet': 'Créer un Portefeuille',
  'generate_mnemonic': 'Générer un Mnémonique',

  // Divers
  'select_currency': 'Sélectionner la devise',
  'select_language': 'Sélectionner la langue',
  'enable_tutorial': 'Activer le tutoriel',
  'disable_tutorial': 'Désactiver le tutoriel',
  'resetting_app': 'Réinitialisation de l’application...',
  'app_reset_success': 'L’application a été réinitialisée.',
  'confirm_reset': 'Êtes-vous sûr de vouloir réinitialiser?',
  'confirm_exit': 'Êtes-vous sûr de vouloir quitter?',
  'import_wallet_descriptor': 'Importer le descripteur du portefeuille',
  'edit_wallet_name': 'Modifier le nom du portefeuille',
  'descriptor_cannot_be_empty': 'Le descripteur ne peut pas être vide',
  'descriptor_valid': 'Le descripteur est valide',
  'navigate_wallet': 'Naviguer vers le portefeuille',
  'public_keys_with_alias': 'Clés publiques avec alias',
  'create_import_message':
      'Gérez vos portefeuilles Bitcoin partagés en toute simplicité ! Que vous créiez un nouveau portefeuille ou en importiez un existant, nous sommes là pour vous aider.',
  'setting_wallet': 'Configuration de votre portefeuille...',
  'morning_check': "🌅 Bonjour ! Il est temps de rafraîchir !",
  'afternoon_check':
      "🌞 Vérification de l’après-midi ! Faites un rafraîchissement !",
  'night_check': "🌙 Rafraîchissement nocturne ? Pourquoi pas !",
  'processing': 'Traitement en cours...',
  'no_connection': '🌐 Pas de connexion Internet',
  'connect_internet':
      'Votre portefeuille doit se synchroniser avec la blockchain.\n\nVeuillez vous connecter à Internet pour continuer.',
  'refreshing': 'Actualisation...',
  'request_sent':
      'Requête envoyée, vérifiez votre solde dans quelques minutes !',
  'select_custom_fee': 'Sélectionner des frais personnalisés',

  // Messages généraux de l'assistant
  'assistant_welcome':
      'Bonjour ! Je suis Hoshi 🤖, ton assistant sur SharedHaven. Appuie sur l’icône d’aide en haut à droite et maintiens un élément pour obtenir des infos.',

  // Configuration et vérification du code PIN
  'assistant_pin_setup_page':
      'Crée un code PIN à 6 chiffres pour chiffrer les données de ton portefeuille. **Ne l’oublie pas**—il protège tes fonds. 🔐',
  'assistant_pin_verification_page':
      'Entre ton code PIN pour vérifier l’accès à ton portefeuille. Ta sécurité avant tout !',

  // Création et gestion du portefeuille
  'assistant_ca_wallet_page':
      'Ici, tu peux **générer une nouvelle phrase mnémonique de 12 mots** ou **importer un portefeuille existant**. **Conserve-la en lieu sûr !** 🛡️',
  'assistant_create_wallet':
      'Appuie ici pour **créer un portefeuille personnel** ou **importer un portefeuille existant avec ta mnémonique**.',
  'assistant_generate_mnemonic':
      'Appuie ici pour **générer une phrase mnémonique**. **Note-la et conserve-la précieusement !** 📝🔑',

  // Page du portefeuille personnel
  'assistant_wallet_page':
      'Bienvenue sur votre **tableau de bord du portefeuille personnel**. Ici, vous pouvez consulter vos soldes, envoyer des transactions et gérer vos fonds. 💰',
  'assistant_personal_info_box':
      'Cette boîte contient les informations clés de votre portefeuille. **Appuyez longuement sur un élément** pour découvrir des fonctionnalités supplémentaires ! ⚡',
  'assistant_personal_transactions_box':
      'Consultez vos **dernières transactions** ici. **Appuyez sur une transaction** pour voir tous les détails, les confirmations et la répartition des frais.',
  'assistant_personal_available_balance':
      'Ce bouton calcule votre **solde maximal disponible** en fonction du destinataire et des frais de transaction. **Saisissez d\'abord un destinataire** pour garantir l\'exactitude ! 🏦',

  // Gestion des clés publiques et privées
  'assistant_private_data':
      'Vos données privées sont **protégées par votre code PIN**. Saisissez-le ici pour accéder aux détails chiffrés de votre portefeuille. 🔐',
  'assistant_pub_key_data':
      'Appuyez ici pour récupérer votre **clé publique**—vous en aurez besoin plus tard pour configurer un portefeuille partagé.',

  // Boutons de transaction
  'assistant_send_button':
      'Créez une **nouvelle transaction Bitcoin** et envoyez des fonds à un destinataire. 💸',
  'assistant_sign_button':
      'Signez une **PSBT (Transaction Bitcoin Partiellement Signée)** pour autoriser une transaction de portefeuille partagé.',
  'assistant_scan_button':
      'Scannez un **QR code Bitcoin** pour entrer rapidement une adresse de destinataire et envoyer des fonds. 📷',
  'assistant_receive_button':
      'Affichez et partagez votre **QR code d\'adresse Bitcoin** pour recevoir des paiements.',

  // Fonctionnalités du portefeuille partagé
  'assistant_shared_wallet':
      'Bienvenue dans votre **portefeuille partagé** ! 🚀 Pensez-y comme à un **portefeuille Bitcoin amélioré**, avec des transactions multisig, des règles de dépenses et une sécurité renforcée en équipe.',
  'assistant_shared_spending_path_box':
      'Voici vos **chemins de dépenses disponibles**—des règles définissant comment les fonds peuvent être dépensés. Remplissez les conditions et vous pourrez accéder au montant indiqué. 💡',
  'assistant_shared_available_balance':
      'Dans un portefeuille partagé, ce bouton calcule le **solde disponible en fonction du chemin de dépenses sélectionné**. **Ajoutez un destinataire en premier** pour obtenir un montant précis ! ⚡',
  'assistant_shared_path_selected':
      'Pas besoin de choisir un chemin manuellement—**le meilleur est automatiquement sélectionné pour vous** ! 😉',
  'assistant_shared_path_dropdown':
      'Vous préférez sélectionner un chemin de dépenses manuellement ? **Choisissez-en un parmi vos options disponibles**. 🔽',

  // Envoi de transactions dans un portefeuille partagé
  'assistant_send_sw_dialog1':
      'Saisissez d\'abord le **montant**, et les **chemins de dépenses non disponibles seront automatiquement désactivés**. **Plus de confusion, juste de la clarté !** 🎯',
  'assistant_send_dialog2':
      '⚠️ **Vérifiez toujours les adresses des destinataires !** Envoyer des fonds à une mauvaise adresse entraîne **une perte définitive**—les transactions Bitcoin sont irréversibles. 🔍',

  // PSBT (Transactions Bitcoin Partiellement Signées)
  'assistant_psbt_dialog1':
      'Avant de signer une **PSBT**, **vérifiez soigneusement** tous les détails de la transaction. ✅ Le bouton **Décoder** vous permet de voir plus d\'informations—il ne signera rien !',
  'assistant_psbt_dialog2':
      'Cette section fournit un aperçu de votre **PSBT**. **Ne signez que les transactions de sources fiables**—ne signez jamais une PSBT provenant d\'une source inconnue. 🔐',

  // Détails des transactions
  'assistant_transactions_dialog1':
      'Besoin de plus de détails ? **Consultez l\'explorateur Mempool** pour voir les données de transaction en temps réel, y compris les confirmations et les frais. 🌐',
  'assistant_transactions_dialog2':
      'Voici les **frais de transaction**—une petite somme payée aux mineurs pour **prioriser votre transaction** sur la blockchain. 🏗️',

  // Clés publiques et importation de descripteurs
  'assistant_generate_pub_key':
      'Générez votre **clé publique**, que vous pouvez partager avec d\'autres pour configurer un portefeuille partagé. 🔑',
  'assistant_select_file':
      'Au lieu de saisir un descripteur manuellement, **importez un fichier JSON** contenant toutes les données nécessaires pour votre portefeuille partagé. 📂',
  'assistant_import_sw_button':
      'Après avoir vérifié votre **descripteur et votre clé publique**, appuyez ici pour **importer et accéder à votre portefeuille partagé**.',

  // Importation d'un portefeuille partagé
  'assistant_import_shared_tip1':
      'Vous saisissez un descripteur manuellement ? Pas de souci—**des noms et alias aléatoires seront générés automatiquement**. Vous pourrez les modifier plus tard !',
  'assistant_import_shared_tip2':
      'Votre **clé publique** peut être partagée avec d\'autres, mais **ne partagez jamais votre clé privée** ! Gardez-la en sécurité à tout prix. 🔑❌',
  'assistant_import_shared_tip3':
      'Faites attention aux **erreurs affichées au-dessus du champ du descripteur**—elles fournissent **des indices sur ce qui ne va pas dans votre saisie** ! ⚠️',

  // Création d'un portefeuille partagé
  'assistant_create_shared_tip1':
      'Vous souhaitez supprimer un alias ou un bloc de condition ? **Balayez vers la gauche ou la droite** pour le retirer ! 🔄',

  // Seuil & règles multisignatures
  'assistant_threshold':
      'Le **seuil** représente le nombre de signatures requises parmi les utilisateurs du portefeuille partagé. **Exemple :** Un portefeuille 2-sur-3 nécessite **2 approbations** avant d’autoriser une dépense. Il **ne peut pas dépasser le nombre total d’utilisateurs**. 🔐',

  // Ajout de clés publiques à un portefeuille partagé
  'assistant_add_pub_key_tip1':
      'Les alias permettent d’identifier plus facilement **quelle clé publique appartient à quel utilisateur**—pratique pour gérer les signatures. 🏷️',
  'assistant_add_pub_key_tip2':
      'Vous pouvez **modifier les alias plus tard** si nécessaire.',

  // Timelock (Conditions de dépense basées sur le temps)
  'assistant_add_timelock_tip1':
      'La valeur **"Older"** représente le nombre de **blocs** devant être validés avant que les fonds ne deviennent disponibles. **Chaque bloc prend environ 10 minutes.** ⏳',
  'assistant_add_timelock_tip2':
      'Un **UTXO (Unspent Transaction Output)** correspond à une quantité de Bitcoin confirmée. Une fois que son **nombre de confirmations atteint la valeur "Older"**, il devient accessible selon la règle définie. 🏦',
  'assistant_add_timelock_tip3':
      'Vous pouvez également ajouter un **seuil à l’intérieur d’une condition timelock**—ce qui signifie que **plusieurs utilisateurs doivent approuver la dépense après un certain temps**.',

  // Création d’un descripteur
  'assistant_create_descriptor':
      'Appuyez sur le bouton ci-dessous pour **générer un récapitulatif de la configuration de votre portefeuille partagé**. 📝✅',

  // Configuration & vérification du PIN (Conseils supplémentaires)
  'assistant_pin_setup_page_tip1':
      'Définissez votre **code PIN** pour commencer votre aventure avec **SharedHaven** ! 🔐',
  'assistant_pin_setup_page_tip2':
      'Choisissez un **PIN sécurisé** et **mémorisez-le bien**—il ne pourra pas être réinitialisé facilement !',
  'assistant_pin_verify_page_tip1':
      'Vérifiez votre **PIN** pour continuer. Cela garantit que vous seul avez accès à votre portefeuille. ✅',

  // Conseils généraux sur la page du portefeuille
  'assistant_wallet_page_tip1':
      'Maintenez enfoncé sur les boutons ou appuyez sur les **icônes "?"** pour afficher des infos et des astuces supplémentaires ! 💡',
  'assistant_wallet_page_tip2':
      'N’oubliez pas, **une connexion Internet est nécessaire** pour synchroniser votre portefeuille avec la blockchain. 🌍',
  'assistant_wallet_page_tip3':
      'Pensez à rafraîchir votre portefeuille régulièrement pour **être à jour avec les dernières transactions**. 🔄',

  // Conseils généraux & valeurs par défaut
  'assistant_shared_page':
      'Gérez ou créez des **portefeuilles partagés** en toute simplicité !',
  'assistant_settings':
      'Personnalisez votre expérience dans **les paramètres** ! 🎛️',
  'assistant_default':
      'Comment puis-je vous aider aujourd’hui ? **Appuyez sur moi pour des conseils !** 🤖',
  'assistant_create_shared':
      'Dans cette section, vous pouvez **créer un nouveau portefeuille partagé**.',
  'assistant_import_shared':
      'Dans cette section, vous pouvez **importer un portefeuille partagé existant**.',

  'initial_instructions_title': 'Bienvenue sur SharedHaven',
  'initial_instructions':
      'Vous voulez en savoir plus sur nous ? Visitez {x} !\nRepérez les icônes “?” dans toute l’application — touchez-les à tout moment pour obtenir de l’aide grâce à notre assistant intégré.',
  'got_it': 'Compris !',
  'mainnet_switch': 'Passer au réseau principal ?',
  'mainnet_switch_text':
      'Vous êtes sur le point de passer au réseau principal de Bitcoin.\n\nLes transactions ici sont réelles et irréversibles.\nÊtes-vous sûr de vouloir continuer ?',
  'continue': 'Continuer',
  'paste': 'Coller',
  'clear': 'Effacer',
  'enter_pub_keys': 'Saisir les clés publiques',
  'enter_multisig': 'Saisir la politique multisig',
  'add_multisig': 'Ajouter une configuration multisig',
  'assistant_default_tip1':
      'Besoin d’aide ? Touchez l’icône “?” à tout moment pour obtenir de l’assistance via notre guide intégré.',
  'assistant_default_tip2':
      'Vous pouvez toujours revenir ici pour revoir ou modifier la configuration de votre portefeuille.',
  'assistant_enter_pub_keys':
      'Chaque participant doit fournir sa clé publique. Assurez-vous que toutes les clés sont correctes avant de continuer !',
  'assistant_enter_multisig':
      'Définissez le nombre de signatures requises pour dépenser les fonds de ce portefeuille — par exemple, 2 sur 3 signifie deux signatures sur un total de trois.',
  'assistant_enter_timelock':
      'Définissez un verrou temporel facultatif si vous souhaitez que vos fonds ne soient dépensables qu’après un certain délai ou une certaine hauteur de bloc.',
  'share_descriptor': 'Partager le descripteur',

  "next": "Suivant",
  "scroll_to_continue": "Faites défiler pour continuer",
  "legal_disclaimer_title": "Avertissement légal",

  "assistant_goto_import_wallet": "Appuie ici et importons ton portefeuille !",
  "assistant_goto_create_wallet":
      "Prêt à créer un nouveau portefeuille ? Je peux t’aider.",
  "goto_import_wallet": "Aller à l’importation du portefeuille",
  "one_or_more_answers_are_wrong":
      "Une ou plusieurs réponses sont incorrectes. Réessaie.",
  "pick_the_right_word": "Sélectionne le mot correct",
  "verify_mnemonic": "Vérifie ta phrase de récupération",
  "create_single_wallet": "Créer un nouveau portefeuille personnel",
  "import_single_wallet": "Importer ton portefeuille personnel",
  "goto_create_wallet": "Aller à la création du portefeuille",
  "select_word": "Choisis le mot correct",
  "import_personal_wallet": "Importer un portefeuille personnel",
};
