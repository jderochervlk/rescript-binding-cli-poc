let picoCdn = "https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"

let home = () =>
  View.element("main", ~attrs=[View.Attr.string("class", "container")], ~children=[
    View.element("h1", ~children=[View.text("ReScript Bindings")], ()),
    View.element("form", ~attrs=[View.Attr.string("method", "get"), View.Attr.string("action", "/")], ~children=[
      View.element("input", ~attrs=[
        View.Attr.string("type", "search"),
        View.Attr.string("name", "q"),
        View.Attr.string("placeholder", "Search package names"),
      ], ()),
      View.element("button", ~attrs=[View.Attr.string("type", "submit")], ~children=[View.text("Search")], ()),
    ], ()),
    View.element("p", ~children=[View.text("No bindings found.")], ()),
  ], ())

let document = (~title: string, body: unit => View.node) =>
  SSR.renderDocument(
    ~head=`<title>${SSR.Html.escape(title)}</title><meta name="color-scheme" content="light dark" />`,
    ~styles=[picoCdn],
    body,
  )
