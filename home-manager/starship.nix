{...}:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    
    settings = {
      command_timeout = 300000;  # 5 minutes in milliseconds
      format = ''
        [╭─](bold blue) $directory$direnv$git_branch$git_status$kubernetes$nix_shell$terraform$aws$python$fill$custom[─](bold blue)
        [╰─](bold blue) $character'';

      directory = {
        style = "bold cyan";
        truncation_length = 4;
        truncate_to_repo = true;
        format = "[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        format = "[$symbol$branch]($style) ";
        symbol = "󰙯 ";  # nf-md-git
        style = "bold purple";
        ignore_branches = [ "master" "main" ];
      };

      git_status = {
        style = "bold yellow";
        format = "([$all_status$ahead_behind]($style)) ";
        conflicted = "󰕚 ";  # nf-md-source_branch_sync
        ahead = "⇡$count ";
        behind = "⇣$count ";
        diverged = "⇕⇡$ahead_count⇣$behind_count ";
        untracked = "󰛑 $count ";  # nf-md-help_circle_outline
        stashed = "󰆓 ";  # nf-md-package
        modified = "󰝤 $count ";  # nf-md-circle_edit
        staged = "󰐕 $count ";  # nf-md-plus_circle
        renamed = "󰁕 $count ";  # nf-md-arrow_right_circle
        deleted = "󰍴 $count ";  # nf-md-minus_circle
      };

      kubernetes = {
        format = "[$symbol$context( \($namespace\))]($style) ";
        style = "bold blue";
        symbol = "󱃾 ";  # nf-md-kubernetes
        disabled = false;
      };

      nix_shell = {
        format = "[$symbol$state( \($name\))]($style) ";
        symbol = "󱄅 ";  # nf-md-nix
        style = "bold blue";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold green)";
      };

      # Language versions
      python = {
        format = "[$symbol($version )(\\($virtualenv\\) )]($style)";
        symbol = " ";  # nf-dev-python
        style = "bold yellow";
        pyenv_version_name = true;
        python_binary = ["python3" "python"];
        detect_extensions = ["py" "ipynb" "pyc" "pyd"];
        detect_files = [
          "requirements.txt"
          "pyproject.toml"
          "setup.py"
          "poetry.lock"
          "Pipfile"
          ".python-version"
          "uv.lock"
        ];
        detect_folders = [".venv" "venv" ".tox"];
        version_format = "v\${raw}";
      };

      # Language/tool symbols alternatives
      nodejs.symbol = "󰎙 ";   # nf-md-nodejs (alternative: "󰏗 ")
      golang.symbol = "󰟓 ";   # nf-md-language_go (alternative: "󰆍 ")
      rust.symbol = "󱘗 ";     # nf-md-rust (alternative: "󱤈 ")
      elixir.symbol = "󰡪 ";   # nf-md-elixir (alternative: "󰂯 ")
      lua.symbol = "󰢱 ";      # nf-md-language_lua (alternative: "󰃘 ")
      ruby.symbol = "󰴭 ";     # nf-md-language_ruby (alternative: "󰏧 ")

      # Disabled modules
      jobs.disabled = true;
      battery.disabled = true;
      custom = {
        wakatime = {
          command = ''
            if [ -f ~/.wakatime.cfg ]; then
              # Check if cache file exists and is less than 1 minute old
              cache_file="/tmp/wakatime_cache"
              current_time=$(date +%s)
              cache_time=0
              
              if [ -f "$cache_file" ]; then
                if command -v stat >/dev/null 2>&1; then
                  if stat -f %m "$cache_file" >/dev/null 2>&1; then
                    cache_time=$(stat -f %m "$cache_file")
                  elif stat -c %Y "$cache_file" >/dev/null 2>&1; then
                    cache_time=$(stat -c %Y "$cache_file") 
                  fi
                fi
              fi

              if [ -f "$cache_file" ] && [ "$((current_time - cache_time))" -lt 60 ]; then
                cat "$cache_file"
              else
                # Ensure we use absolute path to wakatime-cli
                wakatime_cli="$(which wakatime-cli)"
                if [ -z "$wakatime_cli" ]; then
                  echo "wakatime-cli not found"
                  exit 1
                fi
                
                # Get current directory for debugging
                pwd_output="$(pwd)"
                echo "Current dir: $pwd_output" >> /tmp/wakatime.log
                
                output=$("$wakatime_cli" --today --output json --verbose 2>>/tmp/wakatime.log)
                if [ -n "$output" ]; then
                  # Shorten the output
                  echo "$output" | jq -r '.text // .grand_total.text // "Processing..."' 2>/dev/null | \
                  sed -E 's/([0-9]+) (hour|hr)(s)? ([0-9]+) min(s)?/\1h\4m/g; 
                          s/([0-9]+) min(s)?/\1m/g; 
                          s/([0-9]+) sec(s)?/\1s/g; 
                          s/([0-9]+) (hour|hr)(s)?/\1h/g; 
                          s/ Coding/ 󰅩 /g; 
                          s/ Browsing/ 󰈈 /g; 
                          s/ Meeting/ 󰥹 /g; 
                          s/ Communicating/ 󰋎 /g; 
                          s/ Code Reviewing/ 󰊤 /g;
                          s/ Writing/ 󱉹 /g;
                          s/ Documentation/ 󰈙 /g;
                          s/ Learning/ 󱨇 /g;
                          s/ Research/ 󰈙 /g;
                          s/ Debugging/ 󰃤 /g;
                          s/ Testing/ 󰙨 /g;
                          s/ Planning/ 󰺕 /g;
                          s/ Design/ 󰈉 /g;
                          s/ Maintenance/ 󰑓 /g;
                          s/ Infrastructure/ 󰡨 /g;
                          s/ Security/ 󰌆 /g;
                          s/ DevOps/ 󰡨 /g;
                          s/ Analytics/ 󰈐 /g;
                          s/,//g' | tee "$cache_file" || echo "No data"
                else
                  echo "$(cat /tmp/wakatime.log | tail -n 1)" | tee "$cache_file"
                fi
              fi
            else
              echo "Not configured"
            fi
          '';
          when = "test -f ~/.wakatime.cfg";
          format = "󰔛 [$output]($style) ";  # nf-md-clock
          style = "bold yellow";
          shell = ["bash" "--noprofile" "--norc"];
          description = "Display WakaTime stats";
        };
      };

      terraform = {
        format = "[$symbol$workspace]($style) ";
        symbol = "󱁢 ";  # nf-md-terraform
        style = "bold 105";
        detect_files = ["main.tf" ".terraform" "terraform.tf" "terraform.tfstate"];
        detect_folders = [
          ".terraform"
          ".terragrunt"
          ];
        disabled = false;
      };

      aws = {
        format = "[$symbol($profile )(\($region\) )]($style)";
        symbol = "󰸏 ";  # nf-md-aws - cleaner AWS logo
        style = "bold yellow";
        region_aliases = {
          "us-east-1" = "ue1";
          "us-west-2" = "uw2";
          "eu-west-1" = "ew1";
          # Add more region aliases as needed
        };
        profile_aliases = {
          "default" = "def";
          # Add more profile aliases as needed
        };
      };

      # Add the fill module configuration
      fill = {
        symbol = "─";
        style = "bold blue";
      };
    };
  };
}
