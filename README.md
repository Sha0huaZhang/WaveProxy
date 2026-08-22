# 🌊 What is WaveProxy？

WaveProxy is **a lightweight embedded command-line proxy configuration tool** written by **Ruby and Shell**, which aimed at resolving **the inconvenience of quickly switching proxies and configuring proxies in batches**.Previously (especially with **GUI tools**), switching proxies and configuring them in batches was a hassle—but now, all you need is **a terminal**.

# Official Website 
[www.proxy.macwave.org](https://proxy.macwave.org)
# 🌊Install WaveProxy
In the terminal, run the following command:
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sha0huaZhang/WaveProxy/main/install.sh)"
```

After installation, run one of the following commands to apply PATH changes:
 ```
 source ~/.zshrc
```  
  
⚠️Important: if you use bash, run `source ~/.bashrc`    

Or simply close and reopen your terminal.

Installation directory: `~/.local/waveproxy/`

# 🌊 Uninstall WaveProxy    

In the terminal, run the following command:
```
/bin/bash -c "INSTALL_DIR=\"\$HOME/.local/waveproxy\"; echo -e \"\033[31mYou are deleting WaveProxy, are you sure? [Y/n]\033[0m\"; read -n 1 -r; echo; if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then echo \"🌊 Uninstall cancelled.\"; exit 0; fi; if [ -d \"\$INSTALL_DIR\" ]; then echo \"🌊 Removing \$INSTALL_DIR...\"; rm -rf \"\$INSTALL_DIR\"; else echo \"🌊 WaveProxy installation directory not found. Skipping.\"; fi; for RC_FILE in \"\$HOME/.zshrc\" \"\$HOME/.bashrc\"; do if [ -f \"\$RC_FILE\" ]; then sed -i '' '/# WaveProxy/d' \"\$RC_FILE\" 2>/dev/null || true; sed -i '' '/export PATH=\".*waveproxy\/bin/d' \"\$RC_FILE\" 2>/dev/null || true; echo \"🌊 Removed WaveProxy PATH entries from \$RC_FILE\"; fi; done; echo \"\"; echo \"🌊 WaveProxy has been uninstalled.\"; echo \"🌊 Please restart your terminal to apply changes.\""   
```

# 🌊 Commands for WaveProxy


Main Program 
---------------
```
waveproxy query <url>            # Query proxy for a URL
waveproxy commandreference       # Print the complete command reference
waveproxy -h, --help             # Show help information
waveproxy -V, --version          # Show version number
waveproxy -s, --silent           # Silent mode (output result only)
waveproxy -v, --verbose          # Verbose mode (output debug info)
waveproxy -f, --fail             # Exit with non-zero code on error
waveproxy --help-all             # Show help for all three commands
waveproxy query <url> --once     # Apply once-only logic to this query
```

Wrapper
----------
```
proxywrap <any command>     # Auto-inject proxy into any command
proxywrap --help-all        # Show help for all three commands
```

Configuration Management
---------------------------
```
proxydeploy                                     # Show current default config name
proxydeploy list                                # View default config content
proxydeploy list @name                          # View specified config content
proxydeploy edit                                # Edit default config
proxydeploy edit @name                          # Edit specified config

proxydeploy run --change-to-default @new @old   # Switch default config
proxydeploy run --print-working-proxy           # Print current working proxy
proxydeploy run --print-default-proxy           # Print default proxy

proxydeploy run --print-detailed-working-proxy  # Print detailed current config
proxydeploy run --print-detailed-default-proxy  # Print detailed default config
proxydeploy run --print-detailed-all-proxy      # Print detailed ALL configs
proxydeploy run --print-all-proxy               # List all configs with markers

proxydeploy run --create-new-proxy @name        # Create and edit a new config
proxydeploy run --enforce-proxy @name [--once]  # Enforce config (session or once)
proxydeploy run --enforce-proxy "url" [--once]  # Enforce proxy address (session or once)
proxydeploy run --enforce-proxy None [--once]   # Force direct connection
proxydeploy run --ignore-proxy @name [--once]   # Ignore config (session or once)
proxydeploy run --ignore-proxy "url" [--once]   # Ignore proxy address (session or once)
proxydeploy run --ignore-proxy None [--once]    # Ignore direct connection
proxydeploy run --provisional-start @name       # Start provisional mode
proxydeploy run --provisional-start "url"       # Start provisional mode
proxydeploy run --provisional-start None        # Start provisional mode with direct connection
proxydeploy run --provisional-end               # End provisional mode

proxydeploy -h, --help                          # Show help information
proxydeploy --help-all                          # Show help for all three commands
```


Environment Variable
-----------------------
```
export WAVEPROXY_CONFIG=name                # Switch to specified config
WAVEPROXY_CONFIG=name waveproxy query <url> # Temporarily switch config (single command)
```

                            

Config File Syntax
---------------------
```File location: ~/.local/waveproxy/proxydeploy@name.txt```


```
Basic structure:
  def proxy:
      let "variable" = "proxy_url"

  [proxy_rule:
      "variable":
          "pattern"
          "pattern"
          ! "exclude_pattern" unless "whitelist1" "whitelist2"
          "pattern" direct
          ? "fallback_variable"
          default: "fallback_variable"
  ]

Element reference:
  let "name" = "url"              Define a proxy variable
  "pattern"                       Match URL pattern (supports * or **)
  ! "pattern"                     Exclude matching URLs (do not use proxy)
  ! "pattern" unless "a" "b" ...  Exclude, but skip exclusion if whitelist matches
  "pattern" direct                Force direct connection
  ? "name"                        Fallback proxy
  default: "name"                 Default proxy if no other rule matches

Wildcards:
  *      Matches one path segment (does not include '/')
  **     Matches any depth (including empty)

Priority (highest to lowest):
  1. direct
  2. ! exclusion (unless whitelist matches)
  3. "pattern" match
  4. ? fallback
  5. default

Indentation rules:
  Must use 4 spaces. Tab is not allowed.
  All rules inside a block must be aligned at the same indent level.

Complete example config:
  def proxy:
      let "home" = "socks5://127.0.0.1:1080"
      let "work" = "http://proxy.company.com:8080"

  [proxy_rule:
      "home":
          "github.com/**"
          "raw.githubusercontent.com/**"
          "api.github.com/**"
          ! "**.github.com/**" unless "https://github.com/**" "raw.githubusercontent.com/**" "api.github.com/**"
          ! "gitlab.internal.company.com"
          ! "mirrors.company.com"
          ! "**.local/**"

      "work":
          "internal.company.com" direct
          ? "home"
          default: "home"
  ]
```


Local File Structure
-----------------------
```~/.local/waveproxy/
├── bin/
│   ├── waveproxy.rb           # Main program (Ruby core)
│   ├── waveproxy -> waveproxy.rb
│   ├── proxywrap.sh           # Universal wrapper
│   ├── proxywrap -> proxywrap.sh
│   ├── proxydeploy.sh         # Configuration management tool
│   └── proxydeploy -> proxydeploy.sh
├── proxydeploy@default.txt    # Default config file
└── COMMAND_REFERENCE.txt      # Complete command reference

