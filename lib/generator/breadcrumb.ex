defmodule Book.Generator.Breadcrumb do
  alias Book.Generator.Link

  require Logger

  @type t :: %__MODULE__{
          content_path: String.t(),
          link: Link.t()
        }

  defstruct content_path: nil,
            link: nil

  def get_all_possible_breadcrumbs() do
    prefix = Application.get_env(:book, :content_path)

    Path.join([prefix, "/**/title"])
    |> Path.wildcard()
    |> Enum.map(fn title_content_path ->
      %__MODULE__{
        content_path: title_content_path,
        link:
          title_content_path
          |> Link.get_by_content_path()
      }
    end)
  end

  def get_breadcrumb_for(%Link{url: url} = link) do
    url_to_check =
      if url |> String.ends_with?(".html") do
        url |> Path.dirname()
      else
        url
      end

    all_possible_bread_crumbs = get_all_possible_breadcrumbs()

    url_to_check
    |> String.split("/", trim: true)
    |> Enum.scan("", fn part, acc -> Path.join(["/", acc, part]) end)
    |> Enum.map(fn x ->
      all_possible_bread_crumbs
      |> Enum.find(fn %__MODULE__{link: %Link{url: breadcrumb_url}} -> breadcrumb_url == x end)
    end)
    |> Enum.map(fn %__MODULE__{link: link} -> link end)
    |> Kernel.++([link])
  end
end
