defmodule Book.Generator.Site do
  alias __MODULE__
  alias Book.Generator.Breadcrumb
  alias Book.Generator.Link
  alias Book.Generator.Menu
  alias Book.Generator.Markdown

  require Logger

  @derive {Inspect,
           except: [
             :ast,
             :html_from_markdown,
             :teaser,
             :teasers,
             :page
           ]}

  @teaser_marker {:comment, [], ["more"]}

  @type t :: %__MODULE__{
          link: Link.t(),
          order_nr: integer(),
          generator_path: String.t(),
          breadcrumb: [Link.t()],
          menu: [Link.t()],
          markdown: String.t(),
          ast: list(tuple()),
          html_from_markdown: String.t(),
          teaser: String.t(),
          teasers: [map()],
          page: String.t(),
          title: String.t()
        }

  defstruct link: nil,
            order_nr: nil,
            breadcrumb: nil,
            menu: nil,
            generator_path: nil,
            markdown: nil,
            ast: nil,
            html_from_markdown: nil,
            teaser: nil,
            teasers: nil,
            page: nil,
            title: nil

  def get_sites() do
    Path.join([Application.get_env(:book, :content_path), "/**/*.md"])
    |> Path.wildcard()
    |> Enum.filter(fn x ->
      case Application.get_env(:book, :draft) do
        true ->
          true

        _ ->
          !String.contains?(x, "draft")
      end
    end)
    |> Enum.map(fn content_path -> get_site(content_path) end)
    |> get_chapter_sites()
  end

  def get_site(content_path) do
    with {:ok, markdown} <- File.read(content_path),
         {:ok, raw_ast, _errormessages} <- Earmark.as_ast(markdown),
         {:ok, ast} <- Markdown.rewrite(raw_ast),
         html_from_markdown <- Earmark.Transform.transform(ast) do
      %Link{url: url} = link = content_path |> Link.get_by_content_path()

      breadcrumb = Breadcrumb.get_breadcrumb_for(link)

      title =
        breadcrumb
        |> Kernel.++([link])
        |> Enum.map(fn %Link{title: title} -> title end)
        |> Enum.join(" - ")

      menu =
        Menu.get_links(content_path)
        |> Enum.map(fn menu_link ->
          if menu_link == link do
            %Link{link | is_active: true}
          else
            menu_link
          end
        end)

      Logger.info("created #{url}")

      %Site{
        link: link,
        order_nr: get_order_number_from(content_path),
        generator_path:
          content_path
          |> get_generator_path(),
        breadcrumb: breadcrumb,
        html_from_markdown: html_from_markdown,
        ast: ast,
        menu: menu,
        title: title,
        teaser:
          case raw_ast 
               |> Enum.any?(fn x ->
                 x == @teaser_marker
               end) do
            true ->
              raw_ast 
              |> Enum.take_while(fn x -> x != @teaser_marker end)
              |> Markdown.rewrite!(:with_first_heading)

            _ ->
              []
          end
          |> Earmark.Transform.transform(),
        markdown: markdown
      }
      |> populate()
    end
  end

  defp get_chapter_sites(sites) do
    chapter_sites =
      Path.join([Application.get_env(:book, :content_path), "/**/title"])
      |> Path.wildcard()
      |> Enum.filter(fn x ->
        case Application.get_env(:book, :draft) do
          true ->
            true

          _ ->
            !String.contains?(x, "draft")
        end
      end)
      |> Enum.map(fn x ->
        Logger.info("found chapter #{x}")

        menu = Menu.get_links(x)

        menu_sites =
          menu
          |> Enum.map(fn menu_link ->
            sites
            |> Enum.find(fn %Site{link: link} -> link == menu_link end)
          end)
          |> Enum.filter(fn site -> !is_nil(site) end)

        Logger.info("found #{length(menu_sites)} sites for chapter #{x}")

        case menu_sites
             |> Enum.any?(fn %Site{teaser: teaser} ->
               teaser != ""
             end) do
          true ->
            Logger.info("at least one site contains a teaser...")
            [%Site{generator_path: generator_path} = first_chapter_site | _rest] = menu_sites

            %Site{
              first_chapter_site
              | generator_path: Path.join([generator_path |> Path.dirname(), "first.html"]),
                teasers: get_teasers(menu_sites)
            }
            |> populate()

          _ ->
            Logger.info("no teaser found. Set up first page for overview")
            [%Site{generator_path: generator_path} = first_chapter_site | _rest] = menu_sites

            %Site{
              first_chapter_site
              | generator_path: Path.join([generator_path |> Path.dirname(), "first.html"])
            }
        end
      end)

    sites ++ chapter_sites
  end

  defp populate(
         %Site{
           html_from_markdown: html_from_markdown,
           breadcrumb: breadcrumb,
           menu: menu,
           title: title,
           teasers: teasers
         } = site
       ) do
    %Site{
      site
      | page:
          EEx.eval_file("lib/template/default.eex",
            body: html_from_markdown,
            bread_crumps: breadcrumb,
            menu: menu,
            title: title,
            teasers: teasers
          )
    }
  end

  defp get_teasers(menu_sites) do
    menu_sites
    |> Enum.filter(fn %Site{teaser: teaser} ->
      teaser != ""
    end)
    |> Enum.map(fn %Site{teaser: teaser, link: %Link{url: url}} ->
      %{
        teaser: teaser,
        url: url
      }
    end)
  end

  defp get_order_number_from(content_path),
    do:
      content_path
      |> Path.basename()
      # first two chars are digits
      |> String.slice(0, 2)
      |> String.to_integer()

  defp get_generator_path(content_path) do
    content_path_without_prefix =
      content_path |> String.replace_prefix(Application.get_env(:book, :content_path), "")

    Path.join([Application.get_env(:book, :generator_path), content_path_without_prefix])
    |> String.replace(~r"[0-9\-]", "")
    |> Path.rootname()
    |> Kernel.<>(".html")
  end
end
