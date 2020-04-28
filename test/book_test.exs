defmodule BookTest do
  use ExUnit.Case

  alias Book.Generator.Site

  setup_all do
    on_exit(fn ->
      File.rm_rf!(Application.get_env(:book, :content_path))
      File.rm_rf!(Application.get_env(:book, :generator_path))
    end)

    File.mkdir_p(Application.get_env(:book, :content_path))
    File.mkdir_p(Application.get_env(:book, :generator_path))

    content =  Application.get_env(:book, :content_path)

    alphabet = for n <- ?a..?z, do: << n :: utf8 >>

    1..3
    |> Enum.map(fn n ->
      filename =
        n
        |> Integer.to_string()
        |> String.pad_leading(2,"0")
        |> Kernel.<> ("-test-#{alphabet |> Enum.at(n-1)}.md")

      Path.join([content, filename])
    end)
    |> Enum.each(fn x -> File.write!(x,"# Test\ntest") end)

    {:ok,
      content: content,
      generator: Application.get_env(:book, :generator_path)}
  end

  test "generatet files", %{content: content, generator: generator} = _context do

    generator_path =
      Site.get_sites()
      |> Enum.map(fn %Site{generator_path: path} -> path end)

    assert generator_path == ["priv/tests/generated/testa.html", "priv/tests/generated/testb.html","priv/tests/generated/testc.html"]


  end
end
