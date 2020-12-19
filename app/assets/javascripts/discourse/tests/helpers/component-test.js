import { TestModuleForComponent, render } from "@ember/test-helpers";
import EmberObject from "@ember/object";
import { setupRenderingTest as EmberSetupRenderingTest } from "ember-qunit";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import TopicTrackingState from "discourse/models/topic-tracking-state";
import User from "discourse/models/user";
import { autoLoadModules } from "discourse/initializers/auto-load-modules";
import createStore from "discourse/tests/helpers/create-store";
import { currentSettings } from "discourse/tests/helpers/site-settings";
import { test } from "qunit";

export function setupRenderingTest(hooks) {
  if (EmberSetupRenderingTest) {
    return EmberSetupRenderingTest.apply(this, arguments);
  }

  let testModule;

  hooks.before(function () {
    const name = this.moduleName.split("|").pop();
    testModule = new TestModuleForComponent(name, {
      integration: true,
    });
  });

  hooks.beforeEach(function () {
    testModule.setContext(this);
    return testModule.setup(...arguments);
  });

  hooks.afterEach(function () {
    return testModule.teardown(...arguments);
  });

  hooks.after(function () {
    testModule = null;
  });
}

if (typeof andThen === "undefined") {
  window.andThen = async function (callback) {
    return await callback.call(this);
  };
}

export default function (name, opts) {
  opts = opts || {};

  if (opts.skip) {
    return;
  }

  test(name, async function (assert) {
    this.site = Site.current();
    this.session = Session.current();

    if (!EmberSetupRenderingTest) {
      // Legacy test environment
      this.registry.register("site-settings:main", currentSettings(), {
        instantiate: false,
      });
      this.registry.register("capabilities:main", EmberObject);
      this.registry.register("site:main", this.site, { instantiate: false });
      this.registry.register("session:main", this.session, {
        instantiate: false,
      });
      this.registry.injection(
        "component",
        "siteSettings",
        "site-settings:main"
      );
      this.registry.injection("component", "appEvents", "service:app-events");
      this.registry.injection("component", "capabilities", "capabilities:main");
      this.registry.injection("component", "site", "site:main");
      this.registry.injection("component", "session", "session:main");

      this.siteSettings = currentSettings();

      const store = createStore();
      this.registry.register("service:store", store, { instantiate: false });
    }

    autoLoadModules(this.container, this.registry);

    if (!opts.anonymous) {
      const currentUser = User.create({ username: "eviltrout" });
      this.currentUser = currentUser;
      this.registry.register("current-user:main", this.currentUser, {
        instantiate: false,
      });
      this.registry.injection("component", "currentUser", "current-user:main");
      this.registry.unregister("topic-tracking-state:main");
      this.registry.register(
        "topic-tracking-state:main",
        TopicTrackingState.create({ currentUser }),
        { instantiate: false }
      );
    }

    if (opts.beforeEach) {
      const store = this.container.lookup("service:store");
      opts.beforeEach.call(this, store);
    }

    await andThen(() => {
      return (render || this.render)(opts.template);
    });

    await andThen(() => {
      return opts.test.call(this, assert);
    }).finally(async () => {
      if (opts.afterEach) {
        await andThen(() => {
          return opts.afterEach.call(opts);
        });
      }
    });
  });
}
