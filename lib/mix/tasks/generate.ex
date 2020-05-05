defmodule Mix.Tasks.Book.Generate do
  use Mix.Task

  alias Book.Generator.Site

  import Book.Helper

  require Logger

  def run(_args) do
    # Mix tasks do not use config.exs settings for Logger
    # https://github.com/elixir-lang/elixir/issues/6016
    Mix.Task.run("app.start")

    sites = Site.get_sites()

    sites
    |> Enum.each(fn %Site{generator_path: generator_path, page: page} ->
      generator_path
      |> Path.dirname()
      |> File.mkdir_p!()

      File.write!(generator_path, page)
      #File.write!(generator_path <> ".gz", :zlib.gzip(page))
    end)

    static_path = Application.get_env(:book, :static_path)
    generator_path = Application.get_env(:book, :generator_path)
    style_path = Application.get_env(:book, :style_path)

    Logger.info("copying static files...")
    "cp -r #{static_path}/* #{generator_path}" |> bash()
    Logger.info("copying css styles...")
    "cp #{style_path}/css/book.css #{generator_path}" |> bash()
  end
end
