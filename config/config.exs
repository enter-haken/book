use Mix.Config

config :book,
  content_path: "priv/content",
  generator_path: "priv/generated",
  static_path: "priv/static",
  style_path: "priv/styles",
  draft: true,
  port: 4040,
  show_adds: false

config :logger, :console,
  format: "$time $metadata[$level] $levelpad$message\n",
  level: :info

import_config "config.#{Mix.env()}.exs"
