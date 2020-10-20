import { visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupDiscourse } from "discourse/tests/helpers/qunit-helpers";
import { response } from "discourse/tests/helpers/create-pretender";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";

module("Acceptance | Category Banners", function (hooks) {
  setupDiscourse(hooks, {
    loggedIn: true,
    siteChanges: {
      categories: [
        {
          id: 5,
          name: "test read only without banner",
          slug: "test-read-only-without-banner",
          permission: null,
        },
        {
          id: 6,
          name: "test read only with banner",
          slug: "test-read-only-with-banner",
          permission: null,
          read_only_banner:
            "You need to video yourself <div class='inner'>doing</div> the secret handshake to post here",
        },
      ],
    },
  });

  test("Does not display category banners when not set", async function (assert) {
    this.server.get("/c/test-read-only-without-banner/5/l/latest.json", () => {
      return response(DiscoveryFixtures["/latest_can_create_topic.json"]);
    });

    await visit("/c/test-read-only-without-banner");

    await click("#create-topic");
    assert.ok(!visible(".bootbox.modal"), "it does not pop up a modal");
    assert.ok(
      !visible(".category-read-only-banner"),
      "it does not show a banner"
    );
  });

  test("Displays category banners when set", async function (assert) {
    this.server.get("/c/test-read-only-with-banner/6/l/latest.json", () => {
      return response(DiscoveryFixtures["/latest_can_create_topic.json"]);
    });

    await visit("/c/test-read-only-with-banner");

    await click("#create-topic");
    assert.ok(visible(".bootbox.modal"), "it pops up a modal");

    await click(".modal-footer>.btn-primary");
    assert.ok(!visible(".bootbox.modal"), "it closes the modal");
    assert.ok(visible(".category-read-only-banner"), "it shows a banner");
    assert.ok(
      find(".category-read-only-banner .inner").length === 1,
      "it allows staff to embed html in the message"
    );
  });
});

module("Acceptance | Anonymous Category Banners", function (hooks) {
  setupDiscourse(hooks, {
    siteChanges: {
      categories: [
        {
          id: 6,
          name: "test read only with banner",
          slug: "test-read-only-with-banner",
          permission: null,
          read_only_banner:
            "You need to video yourself doing the secret handshake to post here",
        },
      ],
    },
  });

  test("Does not display category banners when set", async function (assert) {
    this.server.get("/c/test-read-only-with-banner/6/l/latest.json", () => {
      return response(DiscoveryFixtures["/latest_can_create_topic.json"]);
    });

    await visit("/c/test-read-only-with-banner");
    assert.ok(
      !visible(".category-read-only-banner"),
      "it does not show a banner"
    );
  });
});
