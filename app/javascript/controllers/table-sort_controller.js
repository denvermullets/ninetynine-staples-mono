import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="table-sort"
//
// Turbo handles fetching and swapping the sorted table (the links are data-turbo-stream),
// but a stream response never changes the browser URL. The search, filter, boxset and
// view-mode controllers all rebuild their requests from window.location.search, so without
// this the next thing the user clicks would silently drop the sort.
export default class extends Controller {
  sort(event) {
    const linkParams = new URL(event.currentTarget.href, window.location.origin).searchParams;
    const currentParams = new URLSearchParams(window.location.search);

    currentParams.set("sort", linkParams.get("sort"));
    currentParams.set("direction", linkParams.get("direction"));
    // sorting starts over from the first page
    currentParams.delete("page");

    history.pushState(null, "", `${window.location.pathname}?${currentParams.toString()}`);
  }
}
