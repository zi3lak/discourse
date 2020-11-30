import { registerRouter } from "discourse/mapping-router";

export default {
  name: "map-routes",
  after: "inject-discourse-objects",

  initialize(container, app) {
    let router = registerRouter(app);
    container.registry.register("router:main", router);
  },
};
