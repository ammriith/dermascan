# DermaScan Official Test Suite 📋

This document contains the formalized test cases for the DermaScan application according to the clinical requirements.

| ID | Testcase Description | Input Data | Expected Result | Actual Result | Status |
|:---|:---|:---|:---|:---|:---|
| **TC-AI-01** | Multi-Image Selection | 3 JPEG/PNG images from Gallery | UI displays 3 thumbnails in the horizontal selection grid. | Images display correctly | 🟢 Pass |
| **TC-AI-02** | Camera Capture Integration | Rear camera photo capture | Image is successfully captured and added to the processing list. | Captured image appears | 🟢 Pass |
| **TC-AI-03** | Real-time Mark Detection | Single skin image for scanning | Red bounding boxes appear over detected marks/lesions via AI. | Boxes overlayed on image | 🟢 Pass |
| **TC-AI-04** | Gemini AI Analysis | Image + "Itching" symptom | AIService returns JSON with condition name, severity, and care steps. | Parsed result shown in UI | 🟢 Pass |
| **TC-REC-01** | Patient Search Filter | Name: "John", Phone: "98765" | List filters instantly to show matching patient records. | Real-time filtering active | 🟢 Pass |
| **TC-REC-02** | Patient History Navigation | Tap on "John Doe" record card | Navigates to history view showing all past AI scans and prescriptions. | Successfully navigated | 🟢 Pass |
| **TC-REM-01** | Medication Reminder Sync | Prescription data in Firestore | Patient Dashboard shows a new medication card in the Reminders tab. | Syncing correctly | 🟢 Pass |
| **TC-REM-02** | Follow-up Alert Logic | Follow-up date set to past date | Reminder card shows a red "OVERDUE" badge for past dates. | Overdue logic working | 🟢 Pass |
| **TC-SVC-01** | SMTP Credential Email Delivery | New patient email: "user@test.com" | Recipient receives a branded HTML email with auto-generated password. | Email delivered via Service | 🟢 Pass |
| **TC-SVC-02** | Role-Based Access Routing | Admin Login credentials | App identifies role and directs user to `ClinicStaffDashboard`. | Correct routing active | 🟢 Pass |
| **TC-SVC-03** | Offline AI Fallback | Image scan with no internet | System displays a SnackBar error: "Check your internet connection." | Fallback response active | 🟢 Pass |
| **TC-VAL-01** | Image Format Validation | Uploading a .pdf or .txt file | System prevents upload and shows "Invalid format" error. | - | 🟡 Pending |
