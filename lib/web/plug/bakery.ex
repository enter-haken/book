defmodule Book.Web.Plug.Bakery.Fetch do
  defmacro get_files() do
    static_files = Path.wildcard("priv/generated/**/*.{css,ico,html,htm,txt,json,png,jpg,gif}")

    static =
      static_files
      |> Enum.map(fn file_to_send ->
        request_path =
          file_to_send
          |> String.replace_leading("priv/generated", "")

        data =
          file_to_send
          |> File.read!()

        if String.starts_with?(MIME.from_path(request_path), "text") do
          %{path: request_path, data: ~s(#{data})}
        else
          %{path: request_path, data: data}
        end
      end)

    Macro.escape(static)
  end
end

defmodule Book.Web.Plug.Bakery do
  alias Book.Web.Plug.Bakery.Fetch

  import Plug.Conn

  require Fetch

  require Logger

  @behaviour Plug

  files = Fetch.get_files()

  for %{path: path, data: data} <- files do
    def call(%Plug.Conn{request_path: unquote(path)} = conn, _opts) do
      conn
      |> put_resp_header("Content-Type", MIME.from_path(unquote(path)))
      |> send_resp(200, unquote(data))
      |> halt()
    end

    if path == "/intro.html" do
      def call(%Plug.Conn{request_path: "/"} = conn, _opts) do
        conn
        |> put_resp_header("Content-Type", MIME.from_path(unquote(path)))
        |> send_resp(200, unquote(data))
        |> halt()
      end
    end

    if path |> String.ends_with?("first.html") do
      request_path = path |> String.replace_suffix("/first.html", "")

      def call(%Plug.Conn{request_path: unquote(request_path)} = conn, _opts) do
        conn
        |> put_resp_header("Content-Type", MIME.from_path(unquote(path)))
        |> send_resp(200, unquote(data))
        |> halt()
      end
    end
  end

  def call(conn, _), do: conn

  def init(opts), do: opts
end
