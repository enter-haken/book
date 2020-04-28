defmodule Book.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    port = Application.get_env(:book, :port)

    children = [
      {Plug.Cowboy, scheme: :http, plug: Book.Web.Router, options: [port: port, compress: true]}
    ]

    opts = [strategy: :one_for_one, name: Book.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
