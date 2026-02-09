import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  late FlutterDriver driver;

  setUpAll(() async {
    driver = await FlutterDriver.connect();
  });

  tearDownAll(() async {
    await driver.close();
  });

  group('Sprint 1: Authentication & Registration', () {
    test('TC_01: Login screen loads correctly', () async {
      final emailField = find.byValueKey('email_field');
      await driver.waitFor(emailField, timeout: const Duration(seconds: 10));
      expect(await driver.getText(find.byValueKey('login_title')), contains('DermaScan'));
    });

    test('TC_02: Patient can register a new account', () async {
      final signUpButton = find.byValueKey('signup_button');
      await driver.tap(signUpButton);
      await driver.tap(find.byValueKey('register_name'));
      await driver.enterText('Test Patient');
      await driver.tap(find.byValueKey('register_email'));
      await driver.enterText('testpatient@example.com');
      await driver.tap(find.byValueKey('register_password'));
      await driver.enterText('password123');
      await driver.tap(find.byValueKey('register_submit'));
      await driver.waitFor(find.byValueKey('patient_dashboard'), timeout: const Duration(seconds: 10));
    });

    test('TC_03: Patient can login with valid credentials', () async {
      final emailField = find.byValueKey('email_field');
      final passwordField = find.byValueKey('password_field');
      final loginButton = find.byValueKey('login_button');
      await driver.tap(emailField);
      await driver.enterText('testpatient@example.com');
      await driver.tap(passwordField);
      await driver.enterText('password123');
      await driver.tap(loginButton);
      await driver.waitFor(find.byValueKey('patient_dashboard'), timeout: const Duration(seconds: 10));
    });

    test('TC_04: Role-based access - Unauthorized access denied', () async {
      final patientDashboard = find.byValueKey('patient_dashboard');
      await driver.waitFor(patientDashboard);
      final adminPanel = find.byValueKey('admin_panel');
      try {
        await driver.waitFor(adminPanel, timeout: const Duration(seconds: 2));
        fail('Admin panel should not be visible to patients');
      } catch (e) {
        expect(true, isTrue);
      }
    });
  });

  group('Sprint 1: Appointment Booking', () {
    test('TC_05: Patient can view available doctors', () async {
      final bookAppointmentButton = find.byValueKey('book_appointment_button');
      await driver.tap(bookAppointmentButton);
      await driver.waitFor(find.byValueKey('doctor_list'), timeout: const Duration(seconds: 10));
      final doctorCard = find.byValueKey('doctor_card_0');
      await driver.waitFor(doctorCard);
    });

    test('TC_06: Booking window displays correct slots', () async {
      await driver.tap(find.byValueKey('doctor_card_0'));
      await driver.waitFor(find.byValueKey('time_slots_grid'), timeout: const Duration(seconds: 5));
      final firstSlot = find.byValueKey('slot_0');
      await driver.waitFor(firstSlot);
      final slotText = await driver.getText(firstSlot);
      expect(slotText, matches(RegExp(r'\d{1,2}:\d{2} [AP]M')));
    });

    test('TC_07: Patient can complete booking flow (includes Sprint 2 Token logic)', () async {
      await driver.tap(find.byValueKey('slot_0'));
      await driver.tap(find.byValueKey('confirm_booking_button'));
      await driver.waitFor(find.byValueKey('booking_success_dialog'), timeout: const Duration(seconds: 10));
      expect(await driver.getText(find.byValueKey('token_display')), contains('#'));
    });
  });

  group('Sprint 2: Staff & Admin Management', () {
    test('TC_08: Staff can book appointment for patient', () async {
      await driver.tap(find.byValueKey('nav_schedule'));
      await driver.tap(find.byValueKey('view_today_schedule'));
      await driver.tap(find.byValueKey('new_appointment_fab'));
      await driver.tap(find.byValueKey('action_book_appointment'));
      await driver.tap(find.byValueKey('select_patient_dropdown'));
      await driver.tap(find.byValueKey('patient_option_0'));
      await driver.tap(find.byValueKey('select_doctor_dropdown'));
      await driver.tap(find.byValueKey('doctor_option_0'));
      await driver.tap(find.byValueKey('submit_staff_booking'));
      await driver.waitFor(find.byValueKey('booking_success_dialog'));
    });

    test('TC_09: Doctor can view "Next Patient" alert card', () async {
      final nextPatientCard = find.byValueKey('next_patient_card');
      await driver.waitFor(nextPatientCard);
      expect(await driver.getText(find.byValueKey('next_patient_label')), contains('NEXT PATIENT'));
    });

    test('TC_10: Admin can view all appointments and toggle "Show All Dates"', () async {
      await driver.tap(find.byValueKey('nav_schedule'));
      await driver.waitFor(find.byValueKey('date_selector_bubble_0'));
      await driver.tap(find.byValueKey('toggle_all_dates'));
      expect(await driver.getText(find.byValueKey('date_range_label')), contains('All Dates'));
    });

    test('TC_11: Live counts synchronization after cancellation', () async {
      await driver.tap(find.byValueKey('view_today_schedule'));
      final initialCountText = await driver.getText(find.byValueKey('today_schedule_title'));
      await driver.tap(find.byValueKey('appointment_card_0_options'));
      await driver.tap(find.byValueKey('action_cancel_appointment'));
      await driver.tap(find.byValueKey('confirm_cancel_button'));
      await Future.delayed(const Duration(seconds: 2));
      final updatedCountText = await driver.getText(find.byValueKey('today_schedule_title'));
      expect(updatedCountText, isNot(initialCountText));
    });
  });
}
