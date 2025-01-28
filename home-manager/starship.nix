{...}:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    
    settings = {
      command_timeout = 300000;  # 5 minutes in milliseconds
      format = ''
        [╭─](bold blue) $directory$git_branch$git_status$kubernetes$nix_shell$custom.wakatime
        [╰─](bold blue) $character'';

      directory = {
        style = "bold cyan";
        truncation_length = 4;
        truncate_to_repo = true;
        format = "[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        format = "[$symbol$branch]($style) ";
        symbol = " ";
        style = "bold purple";
        ignore_branches = [ "master" "main" ];
      };

      git_status = {
        style = "bold yellow";
        format = "([$all_status$ahead_behind]($style)) ";
        conflicted = "⚔️ ";
        ahead = "⇡$count ";
        behind = "⇣$count ";
        diverged = "⇕⇡$ahead_count⇣$behind_count ";
        untracked = "?$count ";
        stashed = "📦 ";
        modified = "!$count ";
        staged = "+$count ";
        renamed = "»$count ";
        deleted = "✘$count ";
      };

      kubernetes = {
        format = "[$symbol$context( \($namespace\))]($style) ";
        style = "bold blue";
        symbol = "⎈ ";
        disabled = false;
      };

      nix_shell = {
        format = "[$symbol$state( \($name\))]($style) ";
        symbol = " ";
        style = "bold blue";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold green)";
      };

      # Language versions
      python.symbol = " ";
      nodejs.symbol = " ";
      golang.symbol = " ";
      rust.symbol = " ";
      elixir.symbol = " ";
      lua.symbol = "󰢱 ";
      ruby.symbol = " ";

      # Disabled modules
      jobs.disabled = true;
      battery.disabled = true;

      custom.wakatime = {
        command = ''
          if [ -f ~/.wakatime.cfg ]; then
            output=$(wakatime-cli --today --output json --verbose 2>/tmp/wakatime.log)
            if [ -n "$output" ]; then
              echo "$output" | jq -r '.text // .grand_total.text // "Processing..."' 2>/dev/null || echo "No data"
            else
              echo "$(cat /tmp/wakatime.log | tail -n 1)"
            fi
          else
            echo "Not configured"
          fi
        '';
        when = "test -f ~/.wakatime.cfg";
        format = "[󱑎 $output]($style) ";
        style = "bold yellow";
        shell = ["bash" "--noprofile" "--norc"];
        description = "Display WakaTime stats";
      };
    };
  };
}
