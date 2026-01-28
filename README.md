# Twain-Desk
Qt6 desktop application for document scanning using TWAIN-compatible scanners.

---

## ✨ Features

🖨️ Scanning Capabilities  
**Full TWAIN Protocol Support:** Complete integration with TWAIN-compatible scanners  
**Multiple Scan Modes:** Auto, Flatbed, and Feeder scanning with intelligent detection  
**Direct Scanning:** Option to scan without showing scanner UI for faster workflow  
**Real-time Progress:** Live scanning progress with page-by-page tracking  
**Batch Scanning:** Support for multi-page document scanning  

---

## 🎨 Modern User Interface  

**Fluent WinUI3 Design:** Modern, clean interface following Windows 11 design principles  
**Dark/Light Themes:** Automatic system theme detection with manual override options  
**High Contrast Support:** Full accessibility support for high contrast modes  
**Customizable Window:** Adjustable corner preferences (Windows 11 rounded corners)  
**Responsive Layout:** Adaptive UI that works on different screen sizes  

---

## 🌍 Internationalization  

**Multi-language Support:** English and Arabic localization  
**RTL Layout Support:** Right-to-left layout for Arabic language  
**Dynamic Language Switching:** Change language without restarting the application  
- ⚙️ Advanced Settings  
**DPI Control:** Configurable resolution from 75 to 1200 DPI
**Color Modes:** Auto-detect, Color, Grayscale, and Black & White scanning
**Scan Location Management:** Customizable scan destination folder
**Render Modes:** Quality vs Performance rendering options
**Settings Persistence:** All preferences automatically saved and restored

---

## 📁 File Management  

**Automatic File Organization:** Scanned files automatically organized in designated folders  
**Folder Synchronization:** Real-time sync with scan location  
**File Preview:** Built-in image viewer for scanned documents  
**Status Monitoring:** Comprehensive status view with detailed logging  

---

## 🔧 Technical Features  

**High DPI Support:** Optimized for high-resolution displays  
**GPU Acceleration:** DirectX 11 backend with configurable rendering  
**Memory Efficient:** Optimized image loading and caching  
**Cross-platform Ready:** Built with Qt6 framework (currently Windows-focused due to TWAIN)  

---

## 📸 Screenshots  

<img width="502" height="532" alt="twain-desk-dark" src="https://github.com/user-attachments/assets/3b8e7e08-cca4-454d-9ca1-1265829ebd70" />
<img width="502" height="532" alt="twain-desk-light" src="https://github.com/user-attachments/assets/cf5ba2f1-ae11-4033-ae59-5ea19bcb4a52" />

 ## High Contrast  

<img width="502" height="532" alt="twain-desk-high2" src="https://github.com/user-attachments/assets/35181140-42c6-4f6c-b60e-b35e823fdc53" />
<img width="502" height="532" alt="twain-desk-high" src="https://github.com/user-attachments/assets/4a89087d-df33-4529-a0fe-8ba3cccf47db" />

---

## 🚀 Installation  

**Prerequisites**  
Windows 10/11  
TWAIN-compatible scanner with proper drivers installed  
Visual Studio 2019+ or MinGW compiler  
Qt6.7+  

**Building from Source**  
- Clone the repository  
```markdown
git clone https://github.com/Saif-k93/Twain-Desk.git
```
```markdown
cd Twain-Desk
```
- Configure CMake  
```markdown
mkdir build
```
```markdown
cd build
```
```markdown
cmake ..
```
- Build the project  
```markdown
cmake --build . --config Release
```

---

## 📖 Usage  

Launch TwainDesk - The application will automatically detect available TWAIN sources  
Configure Settings - Adjust DPI, color mode, and scan location as needed  
Start Scanning - Click "Start Scan" to begin the scanning process  
View Results - Scanned documents appear in the main viewing area  
Manage Files - Use the sync button to refresh or clear photos to reset the view  
**Quick Tips**  
**Direct Mode:** Enable "Direct" checkbox for faster scanning without scanner UI  
**DPI Settings:** 300 DPI is recommended for most documents  
**Color Mode:** Use "Auto Detect" for optimal results  

---

## 🔧 Development  

**Technologies Used**  
**Qt6.7+:** Modern C++ framework with QML/Quick  
**CMake:** Build system configuration  
**TWAIN DSM:** Scanner communication library  
**[QWindowKit](https://github.com/stdware/qwindowkit):** Cross-platform window customization framework for Qt Widgets and Qt Quick.  
**Fluent WinUI3:** UI design system  

---

## 🐛 Troubleshooting  

**Common Issues**  
**No scanners detected:** Ensure scanner drivers are properly installed  
**TWAIN errors:** Check that TWAINDSM.dll is in the application directory  
**Language switching:** Some UI elements may require restart for full translation  

---

## 📄 License  

This project is licensed under the Apache 2.0 License - see the LICENSE file for details.

---

## 🤝 Acknowledgments  

- Qt Team for the excellent Qt6 framework  
- TWAIN Working Group for the scanner protocol specification  
- [QWindowKit](https://github.com/stdware/qwindowkit): for custom title bars and window styling  
