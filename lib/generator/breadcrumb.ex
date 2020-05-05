defmodule Book.Generator.Breadcrumb do
  alias Book.Generator.Link

  require Logger

  @type t :: %__MODULE__{
          content_path: String.t(),
          link: Link.t()
        }

  defstruct content_path: nil,
            link: nil

  def all_first_files_in_chapter() do
    content_path = Application.get_env(:book, :content_path)

    Path.join([content_path, "/**"])
    |> Path.wildcard()
    |> Enum.map(fn x -> Path.dirname(x) end)
    |> Enum.uniq()
    |> Enum.map(fn path ->
      first_file =
        File.ls!(path)
        |> Enum.sort()
        |> List.first()

      Path.join([path, first_file])
    end)
    |> Enum.map(fn x ->
      %__MODULE__{
        content_path: x,
        link: x |> Link.get_by_content_path()
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

    all_possible_bread_crumbs = all_first_files_in_chapter()

    links =
      url_to_check
      |> String.split("/", trim: true)
      |> Enum.scan("", fn part, acc -> Path.join(["/", acc, part]) end)
      |> Enum.map(fn x ->
        all_possible_bread_crumbs
        |> Enum.find(fn %__MODULE__{link: %Link{url: breadcrumb_url}} ->
          Path.dirname(breadcrumb_url) == x
        end)
      end)
      |> Enum.map(fn %__MODULE__{link: link} -> link end)
      |> Kernel.++([link])

    if Enum.any?(all_possible_bread_crumbs, fn %__MODULE__{link: %Link{url: breadcrumb_url}} ->
         breadcrumb_url == url
       end) do
      links |> Enum.drop(1)
    else
      links
    end
  end
end
