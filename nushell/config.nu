$env.config.buffer_editor = "hx"
$env.config.edit_mode = 'vi'
$env.config.show_banner = false
$env.config.table.mode = "compact"
$env.config.cursor_shape.vi_normal = "block"
$env.config.cursor_shape.vi_insert = "line"
$env.PROMPT_INDICATOR_VI_NORMAL = ""
$env.PROMPT_INDICATOR_VI_INSERT = ""

use std/log

# --- disable last login message ---
touch ~/.hushlogin

# --- paths ---
use std/util "path add"
path add /usr/local/bin/
path add /opt/homebrew/bin
$env.GOBIN = (go env GOPATH | path join bin)
path add $env.GOBIN
path add ($env.HOME | path join ".cargo/bin")

# --- load vendors ---
# schema:
# {
#   name: name of vendor
#   path: path to vendor file
#   pre_install?: pre-installation command
#   install: installation command that must return a valid nushell file as string
#   post_install?: post-installation command
# }
const apps = [
    {
        name: "starship"
        path: "starship.nu"
        pre_install: "brew install starship"
        install: "starship init nu"
        post_install: "starship preset pure-preset -o ~/.config/starship.toml"
    },
    {
        name: "kubectl_aliases"
        path: "kubectl_aliases.nu"
        install: "http get https://raw.githubusercontent.com/ahmetb/kubectl-aliases/refs/heads/master/.kubectl_aliases.nu"
    },
    {
        name: "zoxide"
        path: "zoxide.nu"
        pre_install: "brew install zoxide"
        install: "zoxide init nushell"
    }
];

$apps | each { |app|
    let full_path = ($nu.vendor-autoload-dirs | path join $app.path)

    if (not ($full_path | path exists)) {
        if ($app.pre_install != null) {
            nu -c $app.pre_install
        }
        mkdir ($full_path | path dirname)
        nu -c $app.install | save -f $full_path
        if ($app.post_install != null) {
            nu -c $app.post_install
        }
        log info $"Loaded ($app.name)"
    }
}

# --- kubectl ----
# load this before vendor kubectl aliases
def --wrapped kubectl [...rest] {
    let cmd = ($rest | get 0)
    if $cmd == "get" {
        ^kubectl ...$rest | detect columns
    } else {
        ^kubectl ...$rest
    }
}

# --- newline between prompts ---
$env.config.hooks = {
    pre_prompt: [{ $env.config.hooks.pre_prompt = [{ print "" }] }]
}
