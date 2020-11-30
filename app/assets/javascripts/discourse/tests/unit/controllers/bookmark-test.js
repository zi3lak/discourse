import {
  discourseModule,
  fakeTime,
  logIn,
} from "discourse/tests/helpers/qunit-helpers";
import KeyboardShortcutInitializer from "discourse/initializers/keyboard-shortcuts";
import { REMINDER_TYPES } from "discourse/lib/bookmark";
import User from "discourse/models/user";
import sinon from "sinon";
import { test } from "qunit";

discourseModule("Unit | Controller | bookmark", function (hooks) {
  let controller;
  function mockMomentTz(dateString) {
    fakeTime(dateString, controller.userTimezone);
  }

  hooks.beforeEach(function () {
    logIn();
    KeyboardShortcutInitializer.initialize(this.container);

    controller = this.getController("bookmark", {
      currentUser: User.current(),
      site: { isMobileDevice: false },
    });
    controller.onShow();
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("showLaterToday when later today is tomorrow do not show", function (assert) {
    mockMomentTz("2019-12-11T22:00:00");

    assert.equal(controller.get("showLaterToday"), false);
  });

  test("showLaterToday when later today is after 5pm but before 6pm", function (assert) {
    mockMomentTz("2019-12-11T15:00:00");
    assert.equal(controller.get("showLaterToday"), true);
  });

  test("showLaterToday when now is after the cutoff time (5pm)", function (assert) {
    mockMomentTz("2019-12-11T17:00:00");
    assert.equal(controller.get("showLaterToday"), false);
  });

  test("showLaterToday when later today is before the end of the day, show", function (assert) {
    mockMomentTz("2019-12-11T10:00:00");

    assert.equal(controller.get("showLaterToday"), true);
  });

  test("nextWeek gets next week correctly", function (assert) {
    mockMomentTz("2019-12-11T08:00:00");

    assert.equal(controller.nextWeek().format("YYYY-MM-DD"), "2019-12-18");
  });

  test("nextMonth gets next month correctly", function (assert) {
    mockMomentTz("2019-12-11T08:00:00");

    assert.equal(controller.nextMonth().format("YYYY-MM-DD"), "2020-01-11");
  });

  test("laterThisWeek gets 2 days from now", function (assert) {
    mockMomentTz("2019-12-10T08:00:00");

    assert.equal(controller.laterThisWeek().format("YYYY-MM-DD"), "2019-12-12");
  });

  test("laterThisWeek returns null if we are at Thursday already", function (assert) {
    mockMomentTz("2019-12-12T08:00:00");

    assert.equal(controller.laterThisWeek(), null);
  });

  test("showLaterThisWeek returns true if < Thursday", function (assert) {
    mockMomentTz("2019-12-10T08:00:00");

    assert.equal(controller.showLaterThisWeek, true);
  });

  test("showLaterThisWeek returns false if > Thursday", function (assert) {
    mockMomentTz("2019-12-12T08:00:00");

    assert.equal(controller.showLaterThisWeek, false);
  });
  test("tomorrow gets tomorrow correctly", function (assert) {
    mockMomentTz("2019-12-11T08:00:00");

    assert.equal(controller.tomorrow().format("YYYY-MM-DD"), "2019-12-12");
  });

  test("startOfDay changes the time of the provided date to 8:00am correctly", function (assert) {
    let dt = moment.tz(
      "2019-12-11T11:37:16",
      controller.currentUser.resolvedTimezone(controller.currentUser)
    );

    assert.equal(
      controller.startOfDay(dt).format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 08:00:00"
    );
  });

  test("laterToday gets 3 hours from now and if before half-past, it rounds down", function (assert) {
    mockMomentTz("2019-12-11T08:13:00");

    assert.equal(
      controller.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 11:00:00"
    );
  });

  test("laterToday gets 3 hours from now and if after half-past, it rounds up to the next hour", function (assert) {
    mockMomentTz("2019-12-11T08:43:00");

    assert.equal(
      controller.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 12:00:00"
    );
  });

  test("laterToday is capped to 6pm. later today at 3pm = 6pm, 3:30pm = 6pm, 4pm = 6pm, 4:59pm = 6pm", function (assert) {
    mockMomentTz("2019-12-11T15:00:00");

    assert.equal(
      controller.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 18:00:00",
      "3pm should max to 6pm"
    );

    mockMomentTz("2019-12-11T15:31:00");

    assert.equal(
      controller.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 18:00:00",
      "3:30pm should max to 6pm"
    );

    mockMomentTz("2019-12-11T16:00:00");

    assert.equal(
      controller.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 18:00:00",
      "4pm should max to 6pm"
    );

    mockMomentTz("2019-12-11T16:59:00");

    assert.equal(
      controller.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 18:00:00",
      "4:59pm should max to 6pm"
    );
  });

  test("showLaterToday returns false if >= 5PM", function (assert) {
    mockMomentTz("2019-12-11T17:00:01");
    assert.equal(controller.showLaterToday, false);
  });

  test("showLaterToday returns false if >= 5PM", function (assert) {
    mockMomentTz("2019-12-11T17:00:01");
    assert.equal(controller.showLaterToday, false);
  });

  test("reminderAt - custom - defaults to 8:00am if the time is not selected", function (assert) {
    controller.customReminderDate = "2028-12-12";
    controller.selectedReminderType = controller.reminderTypes.CUSTOM;
    const reminderAt = controller._reminderAt();
    assert.equal(controller.customReminderTime, "08:00");
    assert.equal(
      reminderAt.toString(),
      moment
        .tz(
          "2028-12-12 08:00",
          controller.currentUser.resolvedTimezone(controller.currentUser)
        )
        .toString(),
      "the custom date and time are parsed correctly with default time"
    );
  });

  test("loadLastUsedCustomReminderDatetime fills the custom reminder date + time if present in localStorage", function (assert) {
    mockMomentTz("2019-12-11T08:00:00");
    localStorage.lastCustomBookmarkReminderDate = "2019-12-12";
    localStorage.lastCustomBookmarkReminderTime = "08:00";

    controller._loadLastUsedCustomReminderDatetime();

    assert.equal(controller.lastCustomReminderDate, "2019-12-12");
    assert.equal(controller.lastCustomReminderTime, "08:00");
  });

  test("loadLastUsedCustomReminderDatetime does not fills the custom reminder date + time if the datetime in localStorage is < now", function (assert) {
    mockMomentTz("2019-12-11T08:00:00");
    localStorage.lastCustomBookmarkReminderDate = "2019-12-11";
    localStorage.lastCustomBookmarkReminderTime = "07:00";

    controller._loadLastUsedCustomReminderDatetime();

    assert.equal(controller.lastCustomReminderDate, null);
    assert.equal(controller.lastCustomReminderTime, null);
  });

  test("user timezone updates when the modal is shown", function (assert) {
    User.current().changeTimezone(null);
    let stub = sinon.stub(moment.tz, "guess").returns("Europe/Moscow");
    controller.onShow();
    assert.equal(controller.userHasTimezoneSet, true);
    assert.equal(
      controller.userTimezone,
      "Europe/Moscow",
      "the user does not have their timezone set and a timezone is guessed"
    );
    User.current().changeTimezone("Australia/Brisbane");
    controller.onShow();
    assert.equal(controller.userHasTimezoneSet, true);
    assert.equal(
      controller.userTimezone,
      "Australia/Brisbane",
      "the user does their timezone set"
    );
    stub.restore();
  });

  test("opening the modal with an existing bookmark with reminder at prefills the custom reminder type", function (assert) {
    let name = "test";
    let reminderAt = "2020-05-15T09:45:00";
    controller.model = { id: 1, name: name, reminderAt: reminderAt };
    controller.onShow();
    assert.equal(controller.selectedReminderType, REMINDER_TYPES.CUSTOM);
    assert.equal(controller.customReminderDate, "2020-05-15");
    assert.equal(controller.customReminderTime, "09:45");
    assert.equal(controller.model.name, name);
  });
});
