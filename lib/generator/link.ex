defmodule Book.Generator.Link do
  @type t :: %__MODULE__{
          url: String.t(),
          title: String.t(),
          generator_path: String.t(),
          content_path: String.t(),
          is_active: boolean()
        }

  defstruct url: nil,
            title: nil,
            generator_path: nil,
            content_path: nil,
            is_active: false

  def get_by_content_path(content_path) do
    url =
      content_path
      |> get_generator_path()
      |> get_url()

    title =
      if content_path |> String.ends_with?("title") do
        content_path
        |> File.read!()
        |> String.trim()
      else
        with {:ok, title} <-
               content_path
               |> File.read!()
               |> get_title() do
          title
        else
          _ ->
            content_path
            |> Path.basename()
            |> Path.rootname()
            |> String.replace(~r"[0-9\-]", "")
        end
      end

    %__MODULE__{
      generator_path: content_path |> get_generator_path(),
      content_path: content_path,
      url: url,
      title: title
    }
  end

  defp get_generator_path(content_path) do
    content_path_without_prefix =
      content_path |> String.replace_prefix(Application.get_env(:book, :content_path), "")

    root_path =
      Path.join([Application.get_env(:book, :generator_path), content_path_without_prefix])
      |> String.replace(~r"[0-9\-]", "")

    if content_path |> String.ends_with?(".md") do
      root_path
      |> Path.rootname()
      |> Kernel.<>(".html")
    else
      Path.join([root_path |> Path.dirname(), "overview.html"])
    end
  end

  defp get_url(generator_path) do
    url =
      generator_path
      |> String.replace_prefix(Application.get_env(:book, :generator_path), "")

    if url |> String.ends_with?("/overview.html") do
      url |> String.replace_suffix("/overview.html", "")
    else
      url
    end
  end

  defp get_title(markdown),
    do:
      markdown
      |> Earmark.as_ast()
      |> get_title_from_ast()

  defp get_title_from_ast({:ok, [{"h1", [], [title]} | _rest], _error_messages}), do: {:ok, title}
  defp get_title_from_ast({:ok, _ast, _error_messages}), do: {:error, "no h1 tag found"}
  defp get_title_from_ast({:error, _ast, error_messages}), do: {:error, error_messages}
end
