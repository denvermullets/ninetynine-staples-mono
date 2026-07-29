import { Controller } from "@hotwired/stimulus";

const VARIANTS = ["quantity", "foil_quantity", "proxy_quantity", "proxy_foil_quantity"];
const BRAND_NEW = "new";

//
// seeds one bulk edit row's quantity inputs from whichever collection matters:
//   FROM "Brand new" -> the inputs are the resulting TOTAL in TO, seeded with what TO has
//   FROM a collection -> the inputs are how many to MOVE, left at 0, with FROM's counts as a hint
// either way an untouched row is a no-op, which bulk-edit_controller enforces via data-baseline
//
// Connects to data-controller="bulk-edit-row"
export default class extends Controller {
  static targets = ["input", "hint"];
  static values = { quantityPath: String, magicCardId: String, cardUuid: String };

  connect() {
    this.requestToken = 0;
    // the default row is "Brand new" with no destination, so this settles to zeros without a fetch
    this.refresh();
  }

  refresh() {
    const fromSelect = this.fromSelect;
    const toSelect = this.toSelect;
    const from = fromSelect ? fromSelect.value : BRAND_NEW;
    const to = toSelect ? toSelect.value : "";
    const isMove = from !== "" && from !== BRAND_NEW;

    // a slow response must not land on top of a newer selection
    const token = ++this.requestToken;

    this.element.dataset.rowMode = isMove ? "move" : "total";
    this.zeroInputs();
    delete this.element.dataset.baseline;
    this.setHint("");

    if (isMove) {
      this.fetchQuantities(from, token, (counts) => {
        this.setHint(`move from ${this.labelFor(fromSelect)} — has ${this.formatCounts(counts)}`);
      });
    } else if (to) {
      this.fetchQuantities(to, token, (counts) => {
        this.writeInputs(counts);
        this.element.dataset.baseline = JSON.stringify(counts);
        this.setHint(`total in ${this.labelFor(toSelect)}`);
      });
    }
  }

  fetchQuantities(collectionId, token, onLoad) {
    const params = new URLSearchParams({
      collection_id: collectionId,
      magic_card_id: this.magicCardIdValue,
    });
    if (this.cardUuidValue) params.set("card_uuid", this.cardUuidValue);

    fetch(`${this.quantityPathValue}?${params}`, { headers: { Accept: "application/json" } })
      .then((response) => {
        if (!response.ok) throw new Error(`Quantity lookup failed (${response.status})`);
        return response.json();
      })
      .then((data) => {
        if (token !== this.requestToken) return;

        const counts = {};
        VARIANTS.forEach((variant) => {
          counts[variant] = parseInt(data[variant], 10) || 0;
        });
        onLoad(counts);
      })
      .catch((error) => console.error("Bulk edit quantity lookup failed:", error));
  }

  get fromSelect() {
    return this.element.querySelector("select[data-collection-role='from']");
  }

  get toSelect() {
    return this.element.querySelector("select[data-collection-role='to']");
  }

  inputFor(variant) {
    return this.inputTargets.find((input) => input.dataset.variant === variant);
  }

  zeroInputs() {
    this.inputTargets.forEach((input) => {
      input.value = 0;
    });
  }

  writeInputs(counts) {
    VARIANTS.forEach((variant) => {
      const input = this.inputFor(variant);
      if (input) input.value = counts[variant];
    });
  }

  formatCounts(counts) {
    return VARIANTS.map((variant) => counts[variant]).join(" / ");
  }

  labelFor(select) {
    const option = select.options[select.selectedIndex];

    return option ? option.textContent.trim() : "";
  }

  setHint(text) {
    if (this.hasHintTarget) this.hintTarget.textContent = text;
  }
}
