alias la = ls -a
alias ll = ls -la

def conf-apps [] { ["all", "nu", "zed", "starship", "kubernetes", "aerospace", "ssh", "wezterm"] }
# Open config files for various applications
def conf [app: string@conf-apps] {
    match $app {
        "all" => { zed $env.XDG_CONFIG_HOME },
        "nu" => { zed $nu.default-config-dir },
        "zed" => { zed ($env.HOME | path join .config/zed) },
        "starship" => { zed ($env.HOME | path join .config/starship.toml) },
        "kubernetes" => { zed ($env.HOME | path join .kube) },
        "aerospace" => { zed ($env.HOME | path join .config/aerospace) },
        "ssh" => { zed ($env.HOME | path join .ssh) },
        "wezterm" => { zed ($env.HOME | path join .config/wezterm) },
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

    match $cmd {
        "env" => { $secrets | get env | load-env },
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

def --env --wrapped z [...rest: string@z-completion] {
    __zoxide_z ...$rest
}

alias cd = z

alias t = task
