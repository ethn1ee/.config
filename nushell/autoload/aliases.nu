alias la = ls -la
alias ll = ls -l
alias pip = pip3
alias python = python3
alias tailscale = /Applications/Tailscale.app/Contents/MacOS/Tailscale

def conf-apps [] { ["all", "nu", "zed", "starship", "kubernetes", "aerospace", "ssh", "helix", "gemini"] }
# Open config files for various applications
def conf [app: string@conf-apps] {
    match $app {
        "all" => { ^($env.config.buffer_editor) $env.XDG_CONFIG_HOME },
        "nu" => { ^($env.config.buffer_editor) $nu.default-config-dir },
        "zed" => { ^($env.config.buffer_editor) ([ $env.XDG_CONFIG_HOME, zed ] | path join) },
        "starship" => { ^($env.config.buffer_editor) ([ $env.XDG_CONFIG_HOME, starship.toml ] | path join ) },
        "kubernetes" => { ^($env.config.buffer_editor) ([ $env.XDG_CONFIG_HOME, .kube ] | path join) },
        "aerospace" => { ^($env.config.buffer_editor) ([ $env.XDG_CONFIG_HOME, aerospace ] | path join) },
        "ssh" => { ^($env.config.buffer_editor) ([ $env.HOME, .ssh ] | path join) },
        "helix" => { ^($env.config.buffer_editor) ([ $env.XDG_CONFIG_HOME, helix ] | path join) },
        "gemini" => { ^($env.config.buffer_editor) ([ $env.HOME, .gemini ] | path join) },
        _ => { error make --unspanned { msg: $"Unknown app: $app. Supported apps: (conf-apps)" } }
    }
}

# Explore files with yazi
def --env f [...args] {
	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
	yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)
	if $cwd != "" and $cwd != $env.PWD {
		cd $cwd
	}
	rm -fp $tmp
}

# Fuzzy history search
def fh [] {
    history | get command | to text | sk --ansi
}

def secret-cmds [] { ["env", "paths", "add", "get"] }
def secret-paths [] { vault kv list -mount="personal" -format=json | from json }
# Manage secrets with Vault
def --env secret [cmd?:string@secret-cmds, path?: string@secret-paths, data?: record] {
    let mount = "personal"
    let paths = (vault kv list -mount=($mount) -format=json | from json)

    mut secrets = {}
    for path in $paths {
        $secrets = $secrets | merge {
            $path: (vault kv get -mount=($mount) -format="json" $path | from json | get data.data)
        }
    }

    if $cmd == null {
        return $secrets
    }

    let secret_file = ([ $nu.user-autoload-dirs.0 secret.nu ] | path join)
    match $cmd {
        "env" => { $secrets | get env | to nuon | into string | $"($in) | load-env" | save $secret_file -f },
        "paths" => { $paths },
        "get" => {
            if $path == null {
                error make --unspanned { msg: "path is required" }
            }
            $secrets | get $path
        },
        "add" => {
            if $path == null {
                error make --unspanned { msg: "path is required" }
            }
            if $data == null {
                error make --unspanned { msg: "data is required" }
            }
            $data
            | transpose key val
            | each { |pair|
                $pair.key + "=" + $pair.val
            }
            | vault kv patch -mount="personal" -format="json" $path ...$in | from json | get data
        }
        _ => { error make --unspanned  { msg: $"Unknown subcommand. Supported subcommands: (secret-cmds)" } }
    }
}

def z-completion [context: string] {
    let parts = $context | str trim --left | split row " " | skip 1 | each { str downcase }
    let completions = (
        ^zoxide query --list --exclude $env.PWD -- ...$parts
            | lines
            | each { |dir|
                if ($parts | length) <= 1 {
                    $dir
                } else {
                    let dir_lower = $dir | str downcase
                    let rem_start = $parts | drop 1 | reduce --fold 0 { |part, rem_start|
                        ($dir_lower | str index-of --range $rem_start.. $part) + ($part | str length)
                    }
                    {
                        value: ($dir | str substring $rem_start..),
                        description: $dir
                    }
                }
            })
    {
        options: {
            sort: false,
            completion_algorithm: substring,
            case_sensitive: false,
        },
        completions: $completions,
    }
}

def --env --wrapped cd [...rest: string@z-completion] {
    __zoxide_z ...$rest
}

def tmux-sessions [] { tmux ls -F '#{session_name}' | split row "\n" }
def --env t [session?: string@tmux-sessions] {
    if $session == null {
        let selected = tmux-sessions | input list
        tmux a -t $selected
    } else {
        tmux a -t $session
    }
}

def tmake [name: string] {
    let detect_session = (tmux has-session -t $name | complete)

    if ($detect_session.exit_code != 0) {
        tmux new-session -s $name -d
        tmux send-keys -t $"($name):1.1" "hx ." C-m
        tmux new-window -t $name
        tmux select-window -t $"($name):1.1"

        print $"session '($name)' created"
    } else {
        print $"session '($name)' already exists"
    }
}

