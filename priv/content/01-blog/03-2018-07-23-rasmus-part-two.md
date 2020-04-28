# connect the dots 

A few months ago, I [started a little project][rasmusPart1] named [rasmus][sources].
It was my plan, to build a competitive CMS, which I can be proud of.
During the work on `rasmus`, I gather a lot of different information.
I stored some of them as bookmarks. 
Weeks later, I stared on my bookmarks, which I've partly stored over the years and tried to remember, why I saved these links. 
Some of the links were so old, that the presented information has become obsolete.
I noticed, that the context is missing.

The question is, how to save the context?
I took a step back, and started to work on a possible solution for that problem.

On some links, I could remember how I came up with it. 
I found the missing links via Google and started painting a map.
As a result, I got a graph with links as `nodes` and the context as `edges`.

<!--more-->

# architecture

The architecture for `rasmus` looks like

![][concept]

The heart of `rasmus` is its PostgreSQL database.
`ramsus` uses the idea of the [database gate keeper][dbArchitecturePart3].
Data transformation happens within the database, as long no business logic is required.

![][informationflow]

# backend

Because of the event driven approach and the desired robustness, I choose [elixir][elixir] as a backend language. 
I don't expect massive number crunching, so I take the road with the Erlang VM.

A famous web framework in the elixir universe is the [phoenix framework][phoenix].
There is a lot of boiler plate and [mix][mix] tasks involved, so I bootstrap the backend for now and add what is needed.

Phoenix uses [cowboy][cowboy] as a web server and so do I.
With some suitable [plugs][plug] the configuration is a no brainer.

Within the [application behaviour][application] you can define the web server as a child process. 

    Plug.Adapters.Cowboy2, scheme: :http, plug: Web.Router, options: [port: 8080]

The `Web.Router` process uses the [router plug][plugRouter].
You can define the web endpoints of the application here.

There a two ways to access the database

## pub sub database access

When you want to listen to [Postgres notifications][notify], you need to open a channel to the database.

A [GenServer][genserver] can look like

    defmodule Core.Counter do
      use GenServer
    
      def start_link(args) do
        GenServer.start_link(__MODULE__, args, name: :listener)
      end
    
      def init(pg_config) do
        {:ok, pid} = Postgrex.Notifications.start_link(pg_config)
        {:ok, ref} = Postgrex.Notifications.listen(pid, "rasmus")
    
        {:ok, {pid, ref }}
      end
    
      def handle_info({:notification, pid, ref, "rasmus", payload},_) do
        case Jason.decode(payload) do
         {:ok , %{ "id" => id, "state" => "pending", }} -> Core.Manager.perform(id)
   
         # additional pattern matches

         _ -> Logger.warn("got unhandled notification: #{inspect(payload)}")
        end
        {:noreply, {pid, ref}}
      end
    
      def handle_info(_, state) do
        Logger.warn("unhandled info: #{inspect(state)}")
        {:noreply, state}
      end
    end

The notification pattern

    {:notification, connection_pid, ref, channel, payload}

can be matched in `handle_info/2` function, which is defined in the [GenServer behaviour][handleInfo].

## simple database access

If you want to access the `transfer` table of the database, the module looks a little bit different.

    defmodule Core.Inbound do
      use GenServer
    
      # genserver functions
    
      def start_link(args) do
        GenServer.start_link(__MODULE__, args, name: :inbound_worker)
      end
    
      def init(pg_config) do
        {:ok, pid} = Postgrex.start_link(pg_config)
        Logger.info("#{__MODULE__} started.")
    
        {:ok, pid}
      end
    
      def handle_cast({:add, payload}, state) do
        case Postgrex.query(state, "INSERT INTO rasmus.transfer (request) VALUES ($1)", [payload]) do
          {:ok, result} -> Logger.debug("added into transfer: #{inspect(result)}")
          {:error, error} -> Logger.error("adding into transfer failed: #{inspect(error)}. Tried to add #{inspect(payload)}")
        end
        {:noreply, state }
      end
    
      def handle_info(_, state) do
        Logger.warn("unhandled info: #{inspect(state)}")
        {:noreply, state}
      end
    end

First you define the `GenServer` callbacks.
When you want to use them, you have to send messages to the process.

    def add(entity) do
      GenServer.cast(:inbound_worker, {:add, entity})
    end

You don't expect an answer for your add function. 
When the database is ready, it sends a notification to the listener, that the requested task is done, and that you can fetch the result, if it is wished.

# client

The client is responsible for drawing the graph. 
The library [visjs][visjs] provides functions for drawing graphs on a canvas element.
Drawing graphs is not a trivial thing, so this is the best fit for now.

All other user interaction will be done with a UI library.
[material-ui][materialui] is a mature UI library based on react.
Having a react based application, [create-react-app][create-react-app] will give you a good toolchain.

# example

Coming back to the bookmark context problem, I have described some parts of `rasmus` as links to github. 

![][rasmusExample]

This is just a first throw.
If you like the idea, you can test a static [alpha version][alpha] of the frontend, to make yourself a picture.
You can also checkout the [sources][sources], if you like.


[rasmusPart1]: /blog/rasmus.html
[dbArchitecturePart3]: /blog/databasearchitectureparttree.html
[sources]: https://github.com/enter-haken/rasmus
[concept]: /images/rasmus_concept.png
[informationflow]: /images/rasmus_information_flow.png
[alpha]: /example/rasmus/alpha/index.html
[phoenix]: https://phoenixframework.org/
[elixir]: https://elixir-lang.org/
[mix]: https://hexdocs.pm/mix/Mix.html
[cowboy]: https://ninenines.eu/
[plug]: https://hexdocs.pm/plug/readme.html
[plugStatic]: https://hexdocs.pm/plug/Plug.Static.html
[plugCowboy2]: https://hexdocs.pm/plug/Plug.Adapters.Cowboy2.html
[application]: https://hexdocs.pm/elixir/Application.html
[plugRouter]: https://hexdocs.pm/plug/Plug.Router.html
[postgrex]: https://hexdocs.pm/postgrex/readme.html
[notify]: https://www.postgresql.org/docs/current/static/sql-notify.html 
[handleInfo]: https://hexdocs.pm/elixir/GenServer.html#c:handle_info/2
[genserver]: https://hexdocs.pm/elixir/GenServer.html
[create-react-app]: https://github.com/facebook/create-react-app
[visjs]: http://visjs.org/
[materialui]: https://material-ui.com/
[rasmusExample]: /images/rasmus_frontend.png
