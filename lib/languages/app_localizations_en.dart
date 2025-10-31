const Map<String, String> localizedStringsEn = {
  'welcome': 'Welcome to SharedHaven!',
  'version': 'Version',
  'welcoming_description': 'Your Bitcoin wallet companion.',

  // Settings
  'language': 'Select Language',
  'currency': 'Select Currency',
  'settings': 'Settings',
  'settings_message':
      'Customize your global settings to personalize your wallet experience.',
  'reset_settings': 'Reset Default Settings',
  'reset_settings_scaffold': 'Settings reset to default!',
  'reset_app': 'Reset App',
  'begin_journey': 'Begin Your Bitcoin Journey',

  // Network
  'network_banner': 'Testnet Network',
  'network': 'Network',

  // PIN Setup & Verification
  'enter_pin': 'Enter PIN',
  'enter_6_digits_pin': 'Enter Your 6-digit PIN',
  'confirm_pin': 'Confirm PIN',
  'pin_mismatch': 'PIN does not match',
  'pin_must_be_six': 'PIN must be 6 digits',
  'pin_set_success': 'PIN successfully set!',
  'pin_verified': 'PIN verified successfully!',
  'pin_incorrect': 'Incorrect PIN. Try again.',
  'verify_pin': 'Verify PIN',
  'success': 'Successfully',
  'confirm': 'Confirm',
  're_enter_pin': 'Re-enter your PIN',

  // Wallet
  'personal_wallet': 'Personal Wallet',
  'shared_wallet': 'Shared Wallet',
  'pub_key': 'Public Key',
  'address': 'Address',
  'transactions': 'Transactions',
  'wallet_creation': 'Wallet Creation',
  'backup_your_wallet': 'Backup your wallet',
  'wallet_backed_up': 'Wallet backed up successfully!',
  'wallet_not_backed_up': 'Wallet backup failed. Try again.',
  'confirm_wallet_deletion': 'Are you sure you want to delete this wallet?',
  'current_height': 'Current Block Height',
  'timestamp': 'Timestamp',
  'multisig_tx': 'MultiSig Transactions',
  'no_transactions_to_sign': 'No transactions to sign',
  'receive_bitcoin': 'Receive Bitcoin',
  'height': 'Height',

  // Transactions & Blockchain
  'fetching_balance': 'Fetching balance...',
  'balance': 'Balance',
  'pending_balance': 'Pending Balance',
  'confirmed_balance': 'Confirmed Balance',
  'transaction_history': 'Transaction History',
  'transaction_sent': 'Transaction sent',
  'transaction_failed': 'Transaction failed',
  'broadcasting_error': 'Broadcasting error',
  'transaction_fee': 'Transaction Fee',
  'sending_transaction': 'Sending Transaction...',
  'transaction_success': 'Transaction successfully broadcasted!',
  'transaction_failed_retry': 'Transaction failed. Please retry.',
  'internal': 'Internal',
  'sent': 'Sent',
  'received': 'Received',
  'to': 'To',
  'from': 'From',
  'fee': 'Fee',
  'amount': 'Amount',
  'transaction_details': 'Transaction Details',
  'internal_tx': 'Internal Transaction',
  'sent_tx': 'Sent Transaction',
  'received_tx': 'Received Transaction',
  'senders': 'Senders',
  'receivers': 'Receivers',
  'confirmation_details': 'Confirmation Details',
  'status': 'Status',
  'confirmed_block': 'Confirmed at block',
  'confirmed': 'Confirmed',
  'mempool': 'Visit the Mempool',

  // Errors & Warnings
  'error_wallet_creation': 'Error creating wallet with the descriptor provided',
  'error_loading_data': 'Error loading wallet data',
  'error_network': 'Network error. Please check your connection.',
  'error_insufficient_funds':
      'Not enough confirmed funds available. Please wait until your transactions confirm.',
  'error_wallet_locked': 'Wallet is locked. Please enter your PIN.',
  'error_wallet_not_found': 'Wallet not found.',
  'invalid_address': 'Invalid Address',
  'invalid_psbt': 'Invalid PSBT',
  'error_older': 'Error: This Older value already exists!',
  'invalid_descriptor': 'Please enter a valid descriptor',
  'invalid_mnemonic': 'Invalid mnemonic phrase. Please check and try again.',
  'threshold_missing': 'Threshold is missing',
  'public_keys_missing': 'Public keys are missing',
  'your_public_key_missing': 'Your public key is not included',
  'descriptor_name_missing': 'Descriptor name is missing',
  'descriptor_name_exists': 'Descriptor name already exists',
  'error_validating_descriptor': 'Error validating Descriptor',
  'recipient_address_required': 'Please enter a recipient address.',
  'invalid_descriptor_status': 'Invalid Descriptor - ',
  'error_wallet_descriptor':
      'Error creating wallet with the descriptor provided',
  'error_public_key_not_contained':
      'Error: Your public key is not contained in this descriptor',
  'spending_path_required': 'Please select a spending path',
  'generic_error': 'Error',
  'both_fields_required': 'Both fields are required',
  'pub_key_exists': 'This public key already exists',
  'alias_exists': 'This alias already exists',
  'correct_errors': 'Please correct the errors and try again',

  // Sending/Signing UI
  'sending_menu': 'Sending Menu',
  'signing_menu': 'Signing Menu',
  'recipient_address': 'Recipient Address',
  'enter_rec_addr': 'Enter Recipient\'s Address',
  'psbt': 'PSBT',
  'enter_psbt': 'Enter PSBT',
  'enter_amount_sats': 'Enter Amount (Sats)',
  'keys': 'Keys',
  'blocks': 'Blocks',
  'use_available_balance': 'Use Available Balance',
  'select_spending_path': 'Select Spending Path',
  'psbt_created': 'PSBT Created',
  'spending_path': 'Spending Path',
  'signers': 'Signers',
  'confirm_transaction': 'Do you want to sign this transaction?',
  'psbt_not_finalized':
      'This PSBT is not finalized yet, share it to the other users!',

  // File
  'storage_permission_needed':
      'Storage permission is required to save the file',
  'file_already_exists': 'File Already Exists',
  'file_save_prompt':
      'A file with the same name already exists. Do you want to save it anyway?',
  'file_saved': 'File saved to',
  'file_uploaded': 'File uploaded successfully',
  'failed_upload': 'Failed to upload file',

  // SnackBar Messenger
  'copy_to_clipboard': 'Copy to Clipboard',
  'mnemonic_clipboard': 'Mnemonic Copied to Clipboard',
  'pub_key_clipboard': 'Public Key Copied to Clipboard',
  'address_clipboard': 'Address Copied to Clipboard',
  'descriptor_clipboard': 'Descriptor Copied to Clipboard',
  'psbt_clipboard': 'PSBT Copied to Clipboard',
  'transaction_created': 'Transaction Created Successfully',
  'transaction_signed': 'Transaction Signed Successfully',
  'transaction_broadcast': 'Transaction Broadcast Successfully',
  'timelock_condition_removed': 'Timelock condition ({x}) removed',
  'alias_removed': 'removed',
  'multisig_updated': 'Multisig updated successfully',
  'timelock_updated': 'Timelock condition updated successfully',
  'alias_updated': 'Alias updated successfully',
  'sw_info_updated': 'Shared Wallet Details updated successfully',

  // Private Data
  'private_data': 'Private Data',
  'saved_mnemonic': 'Here is your saved mnemonic',
  'saved_descriptor': 'Here is your saved descriptor',
  'saved_pub_key': 'Here is your saved public key',
  'download_descriptor': 'Download Descriptor',
  'wallet_data': 'Wallet Data',

  // Buttons
  'close': 'Close',
  'save': 'Save',
  'cancel': 'Cancel',
  'set_pin': 'Set PIN',
  'reset': 'Reset',
  'submit': 'Submit',
  'add': 'Add',
  'copy': 'Copy',
  'share': 'Share',
  'sign': 'Sign',
  'yes': 'Yes',
  'no': 'No',
  'decode': 'Decode',
  'retry': 'Retry 🔄',

  // Spending Summary
  'spending_summary': 'Spending Summary',
  'type': 'Type',
  'threshold': 'Threshold',
  'transaction_info': 'Transaction Info',
  'can_be_spent': 'can be spent!',
  'unconfirmed': 'Unconfirmed',
  'no_transactions_available': 'No transactions available',
  'value': 'Value',
  'abs_timelock': 'Absolute Timelock',
  'rel_timelock': 'Relative Timelock',

  // Spending Paths
  'immediately_spend': 'You ({x}) can immediately spend',
  'cannot_spend': 'You ({x}) cannot spend any sats at the moment',
  'threshold_required':
      '\n\nA threshold of {x} out of {y} is required. \nYou must coordinate with these keys',
  'spend_alone':
      '\nYou can spend alone. \nThese other keys can also spend independently: ',
  'spend_together': '\nYou must spend together with: ',
  'total_unconfirmed': 'Total Unconfirmed: {x} sats',
  'time_remaining_text': 'Time Remaining',
  'blocks_remaining': 'Blocks Remaining',
  "year": "year",
  "years": "years",
  "month": "month",
  "months": "months",
  "day": "day",
  "days": "days",
  "hour": "hour",
  "hours": "hours",
  "minute": "minute",
  "minutes": "minutes",
  "second": "second",
  "seconds": "seconds",
  "zero_seconds": "0 seconds",
  'sats_available': 'sats available in',
  'future_sats': 'sats will be available in the future',
  'upcoming_funds': 'Upcoming Funds - Tap ⋮ for details',
  'spending_paths_available': 'Spending Paths',
  'no_spending_paths_available': 'No spending paths available',

  // Syncing
  'no_updates_yet': '⏳ No updates yet! Try again later. 🔄',
  'new_block_transactions_detected':
      '🚀 New block & transactions detected! Syncing now... 🔄',
  'new_block_detected': '📦 New block detected! Syncing now... ⛓️',
  'new_transaction_detected': '₿ New transaction detected! Syncing now... 🔄',
  'no_internet': '🚫 No internet! Connect and try again.',
  'syncing_wallet': '🔄 Syncing wallet… Please wait.',
  'syncing_complete': '✅ Syncing Complete!',
  'syncing_error': '⚠️ Oops! Something went wrong.\nError',

  // Import Wallet
  'import_wallet': 'Import Shared Wallet',
  'descriptor': 'Descriptor',
  'generate_public_key': 'Generate Public Key',
  'select_file': 'Select File',
  'valid': 'Descriptor is valid',
  'aliases_and_pubkeys': 'Aliases and Public Keys',
  'alias': 'Alias',
  'navigating_wallet': 'Navigating to your wallet',
  'loading': 'Loading...',
  'idle_ready_import': 'Idle - Ready to Import',
  'descriptor_valid_proceed': 'Descriptor is valid - You can proceed',
  'assistant_scan_qr_descriptor':
      'Tap here to scan a QrCode containing the descriptor you want to import!',
  'scan_qr': 'Scan Qr',

  // Create Shared Wallet
  'create_shared_wallet': 'Create Shared Wallet',
  'descriptor_name': 'Descriptor Name',
  'enter_descriptor_name': 'Enter Descriptor Name',
  'enter_public_keys_multisig': 'Enter Public Keys for Multisig',
  'enter_timelock_conditions': 'Enter Timelock Conditions',
  'older': 'Older',
  'pub_keys': 'Public Keys',
  'create_descriptor': 'Create Descriptor',
  'edit_public_key': 'Edit Public Key',
  'edit_alias': 'Edit Alias',
  'add_public_key': 'Add Public Key',
  'enter_pub_key': 'Enter Public Key',
  'enter_alias': 'Enter Alias Name',
  'edit_timelock': 'Edit Timelock Condition',
  'add_timelock': 'Add Timelock Condition',
  'enter_older': 'Enter Older Value',
  'descriptor_created': 'Descriptor {x} Created',
  'conditions': 'Conditions',
  'aliases': 'Aliases',
  'edit_sw_info': 'Edit Shared Wallet Details',
  'enter_after': 'Enter After Condition',
  'after': 'After',

  // Create Import Single Wallet
  'create_restore': 'Create or Restore Wallet',
  'new_mnemonic': 'New mnemonic generated!',
  'wallet_loaded': 'Wallet loaded successfully!',
  'wallet_created': 'Wallet created successfully!',
  'creating_wallet': 'Creating wallet...',
  'enter_mnemonic': 'Enter Mnemonic',
  'enter_12': 'Enter your 12 word mnemonic in here',
  'create_wallet': 'Create Wallet',
  'generate_mnemonic': 'Generate Mnemonic',

  // Miscellaneous
  'select_currency': 'Select Currency',
  'select_language': 'Select Language',
  'enable_tutorial': 'Enable Tutorial',
  'disable_tutorial': 'Disable Tutorial',
  'resetting_app': 'Resetting App...',
  'app_reset_success': 'App has been reset.',
  'confirm_reset': 'Are you sure you want to reset?',
  'confirm_exit': 'Are you sure you want to exit?',
  'import_wallet_descriptor': 'Import Wallet Descriptor',
  'edit_wallet_name': 'Edit Wallet Name',
  'descriptor_cannot_be_empty': 'Descriptor cannot be empty',
  'descriptor_valid': 'Descriptor is valid',
  'navigate_wallet': 'Navigate to Wallet',
  'public_keys_with_alias': 'Public Keys with Alias',
  'create_import_message':
      'Manage your shared Bitcoin wallets with ease! Whether creating a new wallet or importing an existing one, we’ve got you covered.',
  'setting_wallet': 'Setting up your wallet...',
  'morning_check': '🌅 Good morning! It\'s time for a refresh!',
  'afternoon_check': '🌞 Afternoon check-in! Give it a refresh!',
  'night_check': '🌙 Late night refresh? Why not!',
  'processing': 'Processing...',
  'no_connection': '🌐 No Internet Connection',
  'connect_internet':
      'Your wallet needs to sync with the blockchain.\n\nPlease connect to the internet to proceed.',
  'refreshing': 'Refreshing...',
  'request_sent': 'Request sent, check your balance again in a few minutes!',
  'select_custom_fee': 'Select Custom Fee',

// General Assistant Messages
  'assistant_welcome':
      'Hello, I\'m Hoshi! 🤖 I’m here to guide you through SharedHaven. Tap the help icon in the top right and hold down on anything you need help with!',

// PIN Setup & Verification
  'assistant_pin_setup_page':
      'Set up a 6-digit PIN to encrypt your wallet data locally. **Make sure to remember it**—this PIN secures your funds! 🔐',
  'assistant_pin_verification_page':
      'Enter your PIN to verify access to your wallet. This keeps your funds secure and ensures only you can use them!',

// Wallet Creation & Mnemonic Handling
  'assistant_ca_wallet_page':
      'Here, you can **generate a new 12-word mnemonic** or **import an existing wallet** using your own mnemonic. This mnemonic is your key to your funds—keep it safe! 🛡️',
  'assistant_create_wallet':
      'Tap here to **create a new personal wallet** or **import an existing one** using your mnemonic.',
  'assistant_generate_mnemonic':
      'Tap here to **generate a new 12-word mnemonic**. **Write it down and store it safely!** Losing this means losing access to your wallet. 📝🔑',

// Personal Wallet Page
  'assistant_wallet_page':
      'This is your **personal wallet dashboard**. Here, you can view balances, send transactions, and manage your funds. 💰',
  'assistant_personal_info_box':
      'This box contains key details about your wallet. **Long-press any item** to discover additional features! ⚡',
  'assistant_personal_transactions_box':
      'View your **latest transactions** here. **Tap any transaction** for full details, confirmations, and fee breakdowns.',
  'assistant_personal_available_balance':
      'This button calculates your **maximum available balance** based on the recipient and transaction fees. **Enter a recipient first** to ensure accuracy! 🏦',

// Public & Private Key Handling
  'assistant_private_data':
      'Your private data is **protected by your PIN**. Enter it here to access encrypted wallet details. 🔐',
  'assistant_pub_key_data':
      'Tap here to retrieve your **public key**—you’ll need it later for shared wallet setups.',

// Transaction Buttons
  'assistant_send_button':
      'Create a new **Bitcoin transaction** and send funds to a recipient. 💸',
  'assistant_sign_button':
      'Sign a **PSBT (Partially Signed Bitcoin Transaction)** to authorize a shared wallet transaction.',
  'assistant_scan_button':
      'Scan a **Bitcoin QR code** to quickly input a recipient address and send funds. 📷',
  'assistant_receive_button':
      'View and share your **Bitcoin address QR code** to receive payments.',

// Shared Wallet Features
  'assistant_shared_wallet':
      'Welcome to your **shared wallet**! 🚀 Think of it as a **Bitcoin wallet with superpowers**—offering multisig transactions, spending rules, and team-based security.',
  'assistant_shared_spending_path_box':
      'These are your available **spending paths**—rules that determine how funds can be spent. Meet the conditions, and you can access the indicated amount. 💡 Tap on each icon to discover each functionality.',
  'assistant_shared_available_balance':
      'In a shared wallet, this button calculates the **spendable balance based on the selected spending path**. **Enter a recipient first** to get an accurate amount! ⚡',
  'assistant_shared_path_selected':
      'No need to manually pick a path—**the best one is automatically selected for you**! 😉',
  'assistant_shared_path_dropdown':
      'Want more control? **Select a spending path manually** from your available options. 🔽',

// Sending Transactions in Shared Wallets
  'assistant_send_sw_dialog1':
      'Enter the **amount first**, and any **unavailable spending paths will be automatically disabled**. **No confusion, just clarity!** 🎯',
  'assistant_send_dialog2':
      '⚠️ **Always verify recipient addresses!** Sending funds to the wrong address means **permanent loss**—Bitcoin transactions cannot be undone. 🔍',

// PSBT (Partially Signed Bitcoin Transactions)
  'assistant_psbt_dialog1':
      'Before signing a **PSBT**, double-check all transaction details. ✅ The **Decode** button lets you review additional data—it won’t sign anything!',
  'assistant_psbt_dialog2':
      'This section provides an overview of your **PSBT**. **Only sign transactions you trust**—never sign a PSBT from an unknown source. 🔐',

// Transaction Details
  'assistant_transactions_dialog1':
      'Need more details? **Check the Mempool Explorer** for real-time transaction data, including confirmations and fee rates. 🌐',
  'assistant_transactions_dialog2':
      'This is the **transaction fee**—a small amount of Bitcoin paid to miners to **prioritize your transaction** on the blockchain. 🏗️',

// Public Key & Descriptor Import
  'assistant_generate_pub_key':
      'Generate your **public key**, which you can share with others to set up a shared wallet. 🔑',
  'assistant_select_file':
      'Instead of manually entering a descriptor, **upload a JSON file** that contains all the necessary data for your shared wallet. 📂',
  'assistant_import_sw_button':
      'After verifying your **descriptor and public key**, tap here to **import and access your shared wallet**.',

// Importing a Shared Wallet
  'assistant_import_shared_tip1':
      'Entering a descriptor manually? Don’t worry—**random names and aliases will be generated automatically**. You can change them later!',
  'assistant_import_shared_tip2':
      'Your **public key** can be shared with others, but **never share your private key**! Keep it safe at all costs. 🔑❌',
  'assistant_import_shared_tip3':
      'Watch out for **errors above the descriptor field**—they provide **hints on what’s wrong** with your input! ⚠️',

// Creating a Shared Wallet
  'assistant_create_shared_tip1':
      'Want to delete an alias or condition block? **Swipe left or right** to remove it! 🔄',

// Threshold & Multisig Rules
  'assistant_threshold':
      'The **threshold** is the number of required signers out of the total shared wallet users. **Example:** A 2-of-3 wallet needs 2 approvals before spending. It **cannot exceed the total number of users**. 🔐',

// Adding Public Keys to a Shared Wallet
  'assistant_add_pub_key_tip1':
      'Aliases help identify which **public key** belongs to which user—making it easier to manage signers. 🏷️',
  'assistant_add_pub_key_tip2': 'You can **change aliases later** if needed.',

// Timelock (Time-Based Spending Conditions)
  'assistant_add_timelock_tip1':
      'The **"Older" value** represents the number of **blocks** that must pass before funds become spendable. **Each block is ~10 minutes.** ⏳',
  'assistant_add_timelock_tip2':
      'A **UTXO (Unspent Transaction Output)** is confirmed Bitcoin. When the UTXO’s **confirmation count reaches your Older value**, it becomes spendable under this condition. 🏦',
  'assistant_add_timelock_tip3':
      'You can also add a **threshold inside a timelock condition**—meaning **multiple users must approve after a set time**.',

// Creating a Descriptor
  'assistant_create_descriptor':
      'Tap the button below to **generate a summary of your Shared Wallet setup**. 📝✅',

// PIN Setup & Verification (Extra Tips)
  'assistant_pin_setup_page_tip1':
      'Set your **PIN** to begin your journey with **SharedHaven**! 🔐',
  'assistant_pin_setup_page_tip2':
      'Choose a **strong PIN** and **memorize it**—you won’t be able to reset it easily!',
  'assistant_pin_verify_page_tip1':
      'Verify your **PIN** to continue. This ensures only you have access to your wallet. ✅',

// Wallet Page General Tips
  'assistant_wallet_page_tip1':
      'Hold down on buttons or tap the **? icons** for extra info and tips! 💡',
  'assistant_wallet_page_tip2':
      'Remember, **you need an internet connection** to sync your wallet with the blockchain. 🌍',
  'assistant_wallet_page_tip3':
      'Refresh your wallet periodically to stay **up to date with the latest transactions**. 🔄',

// General Tips & Defaults
  'assistant_shared_page': 'Manage or create **shared wallets** with ease!',
  'assistant_settings': 'Customize your experience in **Settings**! 🎛️',
  'assistant_default': 'How can I assist you today? **Tap me for tips!** 🤖',
  'assistant_create_shared':
      'In this section of the app, you will be able to create a new shared wallet.',
  'assistant_import_shared':
      'In this section of the app, you will be able to import an existing shared wallet.',

  'initial_instructions_title': 'Welcome to SharedHaven',
  'initial_instructions':
      'Want to know more about us? Visit {x}!\nLook out for “?” icons across the app — tap them anytime for guidance from our built-in assistant.',
  'got_it': 'Got it!',
  'mainnet_switch': 'Switch to mainnet?',
  'mainnet_switch_text':
      'You are about to switch to the Bitcoin Mainnet.\n\nTransactions here are real and irreversible.\nAre you sure you want to continue?',
  'continue': 'Continue',
  'paste': 'Paste',
  'clear': 'Clear',
  'enter_pub_keys': 'Enter Public Keys',
  'enter_multisig': 'Enter Multisig Policy',
  'add_multisig': 'Add Multisig Configuration',
  'assistant_default_tip1':
      'Need help? Tap the ? icon anytime to get assistance from our built-in guide.',
  'assistant_default_tip2':
      'You can always come back here to review your wallet setup and change configurations.',
  'assistant_enter_pub_keys':
      'Each participant must provide their public key. Make sure all keys are correct before proceeding!',
  'assistant_enter_multisig':
      'Define how many signatures are required to spend from this wallet — for example, 2-of-3 means two signatures out of three total.',
  'assistant_enter_timelock':
      'Set an optional timelock if you want your funds to become spendable only after a specific time or block height.',
  'share_descriptor': 'Share Descriptor',

  'next': 'Next',
  'scroll_to_continue': 'Scroll to Continue',
  'legal_disclaimer_title': 'Legal Disclaimer',
  'legal_disclaimer': '''
1. Risks related to the use of SharedHaven Wallet
SharedHaven will not be responsible for any losses, damages or claims arising from events falling within the scope of the following five categories:

Mistakes made by the user of any cryptocurrency-related software or service, e.g., forgotten passwords, payments sent to wrong coin addresses, and accidental deletion of wallets.
Software problems of the wallet and/or any cryptocurrency-related software or service, e.g., corrupted wallet file, incorrectly constructed transactions, unsafe cryptographic libraries, malware affecting the wallet and/or any cryptocurrency-related software or service.
Technical failures in the hardware of the user of any cryptocurrency-related software or service, e.g., data loss due to a faulty or damaged storage device.
Security problems experienced by the user of any cryptocurrency-related software or service, e.g., unauthorized access to users' wallets and/or accounts.
Actions or inactions of third parties and/or events experienced by third parties, e.g., bankruptcy of service providers, information security attacks on service providers, and fraud conducted by third parties.

2. Compliance with tax obligations
The users of the wallet are solely responsible to determinate what, if any, taxes apply to their crypto-currency transactions. The owners of, or contributors to, the wallet are NOT responsible for determining the taxes that apply to crypto-currency transactions.

3. No warranties
The wallet is provided on an "as is" basis without any warranties of any kind regarding the wallet and/or any content, data, materials and/or services provided on the wallet.

4. Limitation of liability
Unless otherwise required by law, in no event shall the owners of, or contributors to, the wallet be liable for any damages of any kind, including, but not limited to, loss of use, loss of profits, or loss of data arising out of or in any way connected with the use of the wallet. In no way are the owners of, or contributors to, the wallet responsible for the actions, decisions, or other behavior taken or not taken by you in reliance upon the wallet.

5. Arbitration
The user of the wallet agrees to arbitrate any dispute arising from or in connection with the wallet or this disclaimer, except for disputes related to copyrights, logos, trademarks, trade names, trade secrets or patents.

6. Last amendment
This disclaimer was amended for the last time on October 1st, 2025 ''',
};
