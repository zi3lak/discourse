import Mixin from "@ember/object/mixin";
import { computed } from "@ember/object";
import Category from "discourse/models/category";

export default Mixin.create({
  filterModeInternal: computed(
    "rawFilterMode",
    "filterType",
    "category",
    "noSubcategories",
    function() {
      const rawFilterMode = this.rawFilterMode;
      if (rawFilterMode) {
        return rawFilterMode;
      } else {
        const category = this.category;
        const filterType = this.filterType;

        if (category) {
          let subcategoryFilter = "";

          if (this.noSubcategories === true) {
            subcategoryFilter = "/none";
          } else if (this.noSubcategories === false) {
            subcategoryFilter = "/all";
          }

          return `c/${Category.slugFor(
            category
          )}${subcategoryFilter}/l/${filterType}`;
        } else {
          return filterType;
        }
      }
    }
  ),

  filterMode: computed("filterModeInternal", {
    get() {
      return this.filterModeInternal;
    },

    set(key, value) {
      this.set("rawFilterMode", value);
      const parts = value.split("/");

      if (parts.length >= 2 && parts[parts.length - 2] === "top") {
        this.set("filterType", "top");
      } else {
        this.set("filterType", parts.pop());
      }

      return value;
    }
  })
});
