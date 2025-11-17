This file is part of Shared Haven.
Copyright (C) 2025 [Cortez Hanny]

Shared Haven is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Shared Haven is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Shared Haven  

[![Flutter](https://img.shields.io/badge/Flutter-2.10-blue.svg)](https://flutter.dev)  
[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)  

**Shared Haven** is a Flutter mobile wallet / shared-fund / pooling app (work in progress).  
It lets groups pool funds, share balances, and manage contributions—all in one secure place.

---

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
     alt="Get it on F-Droid"
     height="80">](https://f-droid.org/packages/com.bitcoin.sharedhaven.testnet/)

---

## 📚 Index

- [👩‍💻 Developer Information](#-developer-information)
- [🧭 User Guide](#-user-guide)

---

## 👩‍💻 Developer Information

### 🚀 Features

- Multi-platform (iOS, Android) support via Flutter  
- Account / wallet management  
- Shared group balances and pooled funds  
- Transaction tracking and reconciliation  
- Custom theming, localization, and dark mode  
- Modular architecture for scalability and testing  

---

### 🧱 Architecture Overview

| Module | Purpose |
|---|---|
| **lib/** | Core Flutter app source code |
| **lib/services/** | API, blockchain and storage services |
| **lib/wallet_helpers/** | Data and function helpers |
| **lib/wallet_pages/** | Screens and widgets |

The project follows **Clean Architecture** principles with a clear separation between presentation, domain, and data layers.

---

### 🛠 Getting Started (Dev Setup)

#### Prerequisites

- Flutter SDK (stable channel, v2.10 or higher)  
- Dart SDK  
- Android Studio or VSCode  
- A connected device, emulator

#### Setup Steps

1. Clone the repository  
   ```bash
   git clone https://github.com/cortezhanny124/shared_haven.git
   cd shared_haven
   ```

2. Get dependencies  
   ```bash
   flutter pub get
   ```

3. Run the app  
   ```bash
   flutter run
   ```

4. (Optional) To build for release  
   ```bash
   flutter build apk --release
   ```

---

## 🧭 User Guide

### 💡 Getting Started in the App

1. **Open the App**  
   Launch *Shared Haven* on your device.  

2. **Set up or Restore a Wallet**  
   - You can **paste an existing mnemonic** (12 words) to restore a wallet.  
   - Or **generate a new mnemonic** to create a brand-new wallet securely.  
   - Each word will be displayed in its own box for clarity and safety.

3. **Wallet Creation**  
   Once your mnemonic is entered, the wallet will initialize. You’ll be able to view your Bitcoin address and start using it immediately.

---

### 💸 Sending and Receiving Bitcoin

- **Send Bitcoin** → Tap the **left button** on the main screen.  
  Enter the recipient address and amount, review the details, and confirm.  

- **Receive Bitcoin** → Tap the **right button** to display your wallet’s receiving address or QR code.

---

### 👥 Shared Wallets

Open the **Side Menu → Create or Import Shared Wallet**.  

#### 🏗 Create a Shared Wallet

- Choose between **Multisig** or **Timelocked** configurations.  
- Set up:  
  - Participant keys  
  - Required signature threshold  
  - Optional timelocks for enhanced security  

#### 📥 Import a Shared Wallet

- Paste an existing **descriptor** directly, *or*  
- Upload the exported **.json** file generated from another Shared Haven instance.

---

### ✍️ Signing and Managing Transactions

- Use the **middle button** on the main screen to **sign PSBTs (Partially Signed Bitcoin Transactions)**.  
- Upload the `.psbt` file (downloaded from the app or another user) to see details and finalize signatures.

---

### 🔍 Viewing More Details

- Tap the **👁 Eye icon** or the **⋮ (three dots)** to view detailed wallet or transaction information.  

---

### 🧠 Using the In-App Assistant

Shared Haven includes a built-in **Assistant** to guide you through the app:

- Tap the **❓ Question Mark icon** to activate it.  
- The assistant provides contextual tips on each screen.  
- Tap the assistant to move to the next tip.  
- Tap the dialog window to close it.  
- Tap the question mark again to dismiss the assistant entirely.

---

### 🪙 Summary

Shared Haven aims to make Bitcoin **collaborative, transparent, and secure**.  
Whether you’re managing a small group fund or experimenting with timelocked multisig wallets, the app gives you clear control and visibility every step of the way.

---

**License:** [GNU GPLv3](LICENSE)  
**Repository:** [GitHub – cortezhanny124/shared_haven](https://github.com/cortezhanny124/shared_haven)
