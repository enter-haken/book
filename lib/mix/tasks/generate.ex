defmodule Mix.Tasks.Book.Generate do
  use Mix.Task

  alias Book.Generator.Site
  alias Book.Generator.Link

  import Book.Helper

  require Logger

  def run(_args) do
    # Mix tasks do not use config.exs settings for Logger
    # https://github.com/elixir-lang/elixir/issues/6016
    Mix.Task.run("app.start")

    sites = Site.get_sites()

    sites
    |> Enum.each(fn %Site{generator_path: generator_path, page: page} = site ->
      site
      |> verbose()

      generator_path
      |> Path.dirname()
      |> File.mkdir_p!()

      File.write!(generator_path, page)
    end)

    static_path = Application.get_env(:book, :static_path)
    generator_path = Application.get_env(:book, :generator_path)
    style_path = Application.get_env(:book, :style_path)

    Logger.info("copying static files...")
    "cp -r #{static_path}/* #{generator_path}" |> bash()
    Logger.info("copying css styles...")
    "cp #{style_path}/css/book.css #{generator_path}" |> bash()
  end

  defp verbose(
         %Site{
           generator_path: generator_path,
           link: link,
           title: title,
           menu: menu,
           breadcrumb: breadcrumb
         } = site
       ) do
    Logger.debug("Generating #{title} in #{generator_path}")
    Logger.debug("Link for generated file: #{verbose(link)}")

    breadcrumb
    |> Enum.each(fn x -> Logger.debug("Breadcrumb: \"#{title}\": #{verbose(x)}") end)

    menu
    |> Enum.each(fn x -> Logger.debug("Menu link: \"#{title}\": #{verbose(x)}") end)

    site
  end

  defp verbose(%Link{url: url, title: title, content_path: content_path}),
    do: "#{url}: #{title} (origin: #{content_path})"
end
