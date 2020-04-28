defmodule Book.Web.Router do
  use Plug.Router

  plug(Plug.Logger)
  plug(Book.Web.Plug.Bakery)

  plug(:match)
  plug(:dispatch)

  match _ do
    send_resp(conn, 404, "oops")
  end
end
