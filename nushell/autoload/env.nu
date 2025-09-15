{
    VAULT_ADDR:"https://vault.taehoonlee.cloud",
    VAULT_TOKEN:"hvs.Can513OdunnR1zv3YUL4kcIW",
    EDITOR:"hx",
    GEMINI_CLI_SYSTEM_SETTINGS_PATH: ([ $env.XDG_CONFIG_HOME gemini settings.json ]| path join)
} | load-env

