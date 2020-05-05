defmodule Book.Generator.Menu do
  alias Book.Generator.Link
  alias Book.Generator.Breadcrumb

  def get_links(content_path) do
    File.ls!(content_path |> Path.dirname())
    |> Enum.filter(fn file ->
      file != "title" and !String.contains?(file, "draft") and !String.contains?(file, "license")
    end)
    |> Enum.filter(fn file ->
      case Application.get_env(:book, :draft) do
        true ->
          true

        _ ->
          !String.contains?(file, "draft")
      end
    end)
    |> Enum.map(fn file ->
      full_path = Path.join([content_path |> Path.dirname(), file])

      case File.lstat(full_path) do
        {:ok,
         %File.Stat{
           type: :regular
         }} ->
          %{
            link: full_path |> Link.get_by_content_path(),
            order_nr:
              full_path
              |> Path.basename()
              # first two chars are digits
              |> String.slice(0, 2)
              |> String.to_integer()
          }

        {:ok,
         %File.Stat{
           type: :directory
         }} ->
          %Breadcrumb{link: link} =
            Breadcrumb.all_first_files_in_chapter()
            |> Enum.find(fn %Breadcrumb{content_path: candidate} ->
              full_path == candidate |> Path.dirname()
            end)

          %{
            link: link,
            order_nr:
              file
              |> String.slice(0, 2)
              |> String.to_integer()
          }
      end
    end)
    |> Enum.sort(fn %{order_nr: first}, %{order_nr: second} -> first <= second end)
    |> Enum.map(fn %{link: link} -> link end)
  end
end
