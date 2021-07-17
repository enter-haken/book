# styles builder

FROM node:14.8.0 as styles_builder 

# set working directory
WORKDIR /app

# add `/app/node_modules/.bin` to $PATH
ENV PATH /app/node_modules/.bin:$PATH

# add app

COPY priv/styles/ .

RUN make deep_clean build 

# backend builder

FROM elixir:1.10.4 AS backend_builder

WORKDIR /app

COPY . .

COPY --from=styles_builder /app/css/book.css /app/priv/styles/css/book.css

RUN mix local.hex --force
RUN mix local.rebar --force

RUN apt-get update && \
      apt-get install -y graphviz \
      && rm -rf /var/lib/apt/lists/*

RUN make release

# backend runner

FROM elixir:1.10.4-slim AS runner

WORKDIR /app

COPY --from=backend_builder /app/_build/prod/rel/book .

CMD ["bin/book", "start"]

