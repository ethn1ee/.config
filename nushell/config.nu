$env.config.buffer_editor = "hx"
$env.config.edit_mode = 'vi'
$env.config.show_banner = false
$env.config.table.mode = "compact"
$env.config.cursor_shape.vi_normal = "block"
$env.config.cursor_shape.vi_insert = "line"
$env.config.use_kitty_protocol = true
$env.config.shell_integration = {
    osc2: true
    osc7: true
    osc8: true
}
$env.PROMPT_INDICATOR_VI_NORMAL = ""
$env.PROMPT_INDICATOR_VI_INSERT = ""
$env.ZELLIJ_CONFIG_DIR = ([ $env.XDG_CONFIG_HOME zellij ] | path join)

use std/log

# --- disable last login message ---
touch ~/.hushlogin

# --- paths ---
use std/util "path add"
path add /usr/local/bin/
path add /opt/homebrew/bin
$env.GOBIN = (go env GOPATH | path join bin)
path add $env.GOBIN
path add ([ $env.HOME .cargo bin ] | path join)
path add ([ $env.HOME google-cloud-sdk bin] | path join)
path add ([ $env.HOME .local bin ] | path join)

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
        post_install: null
    },
    {
        name: "zoxide"
        path: "zoxide.nu"
        pre_install: "brew install zoxide"
        install: "zoxide init nushell"
        post_install: null
    },
    {
        name: "jj"
        path: "jj.nu"
        pre_install: "brew install jj"
        install: "jj util completion nushell"
        post_install: null
    }
];

$apps | each { |app|
    let full_path = ([ $nu.default-config-dir vendor autoload ]| path join $app.path)

    if (not ($full_path | path exists)) {
        if ($app.pre_install != null) {
            nu -c $app.pre_install;
        }
        mkdir ($full_path | path dirname);
        nu -c $app.install | save -f $full_path;
        if ($app.post_install != null) {
            nu -c $app.post_install;
        }
        log info $"Loaded ($app.name)";
    }
}

# --- kubectl ----
# load this before vendor kubectl aliases
def --wrapped kubectl [...rest] {
    let cmd = ($rest | get 0);
    match $cmd {
        "get" => (^kubectl ...$rest | detect columns),
        _ => (^kubectl ...$rest),
    }
}

def zellij-update-tabname [] {
    if ("ZELLIJ" in $env) {
        mut tabname = "";
        let dir: string = match (pwd) {
            ($env.HOME) => { "~" },
            _ => { pwd | path basename },
        };
        $tabname = $"[($dir)]";

        try {
            let cmd = (commandline | into string | split words | first);
            $tabname = ( [ $tabname " " $cmd ] | str join );
        };

        zellij action rename-tab $tabname;
    }
}

$env.config.hooks = {
    pre_prompt: [
        { $env.config.hooks.pre_prompt = [{ print "" }] },
    ],
    pre_execution: [
        { zellij-update-tabname }
    ],
    env_change: {
        PWD: [
            { zellij-update-tabname }
        ]
    }
}

