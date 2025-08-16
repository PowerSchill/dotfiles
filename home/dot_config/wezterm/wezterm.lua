local config = require("config")({
  require("config.appearance"),
  require("config.bindings"),
  require("config.fonts"),
  require("config.general"),
  require("config.hyperlinks"),
  require("commands"),
}).config

return config
