defmodule Book.Generator.Markdown do
  require Logger

  import Book.Helper

  def rewrite([possible_first_tag_heading | ast_without_first_heading] = ast) do
    result =
      case possible_first_tag_heading do
        {"h1", _, _} ->
          ast_without_first_heading
          |> Enum.map(&walk/1)

        _ ->
          ast
          |> Enum.map(&walk/1)
      end
      |> Enum.filter(fn row -> !is_nil(row) end)

    {:ok, result}
  end

  def rewrite!(ast, :with_first_heading),
    do:
      ast
      |> Enum.map(&walk/1)
      |> Enum.filter(fn row -> !is_nil(row) end)

  defp walk(
         {"pre", [],
          [
            {"code", [{"class", "{lang=dot}"}], [source]}
          ]}
       ) do
    {image, 0} = "echo '#{source}' | dot -Tpng" |> bash()

    {"p", [],
     [
       {"img",
        [
          {"src", "data:image/png;base64,#{Base.encode64(image)}"},
          {"alt", "alternative text"}
        ], []}
     ]}
  end

  defp walk(
         {"pre", [],
          [
            {"code", [{"class", "tag-cloud"}], [raw_tags]}
          ]}
       ) do
    [heading | tags] =
      raw_tags
      |> String.split("\n")
      |> Enum.map(fn x -> String.trim(x) end)

    {"div", [{"class", "card"}, {"style", "margin: 8px"}],
     [
       {"div", [{"class", "card-content"}],
        [
          {"p", [{"class", "title is-5"}], [heading]},
          {"div", [{"class", "tags"}],
           tags
           |> Enum.map(fn x ->
             {"span", [{"class", "tag is-info"}, {"style", "margin:0.5em;"}], [x]}
           end)}
        ]}
     ]}
  end

  defp walk(
         {"pre", [],
          [
            {"code", [{"class", "experience"}], [experience]}
          ]}
       ) do
    [time, company, _empty_line | raw_description] =
      experience
      |> String.split("\n")

    description =
      raw_description
      |> Enum.map(fn x -> String.trim(x) end)
      |> Enum.chunk_by(fn x -> x == "" end)
      |> Enum.filter(fn x -> x != [""] end)
      |> Enum.map(fn x ->
        {:ok, result, _} =
          x
          |> Enum.join(" ")
          |> Earmark.as_ast()

        result
      end)

    {"div", [{"class", "card"}, {"style", "margin: 8px"}],
     [
       {"div", [{"class", "card-content"}],
        [
          {"div", [{"class", "content"}],
           [
             {"p", [{"class", "title is-5"}], [company]},
             {"p", [{"class", "subtitle is-6"}], [time]},
             {"div", [], [description]}
           ]}
        ]}
     ]}
  end

  defp walk({:comment, [], ["more"]} = teaser_comment = _leave_teaser_comment_as_it_is),
    do: teaser_comment

  defp walk({:comment, [], _all_other_comments_not_needed_in_the_html_output}), do: nil

  defp walk(other),
    do: other
end
