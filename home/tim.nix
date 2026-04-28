{ config, pkgs, lib, ... }:

{
  home.username = "tim";
  home.homeDirectory = "/home/tim";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  # --- shell (zsh + oh-my-zsh) ---

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "alias-finder" "fzf" "git" "mise" ];
    };
    initContent = ''
      # disable magic functions (pasting URLs)
      DISABLE_MAGIC_FUNCTIONS="true"

      # load custom theme
      source ${../dotfiles/zsh/tim-bira-fork.zsh-theme}

      # configure alias-finder plugin
      zstyle ':omz:plugins:alias-finder' autoload yes
      zstyle ':omz:plugins:alias-finder' longer yes
      zstyle ':omz:plugins:alias-finder' exact yes
      zstyle ':omz:plugins:alias-finder' cheaper yes

      # set up zsh functions
      fpath=($fpath ~/.zsh/functions)
      for func in ~/.zsh/functions/*; do
        autoload -U ''${func:t}
      done

      export GPG_TTY=$(tty)
      export EDITOR=vim
      eval "$(mise activate zsh)"

      # set DOTNET_ROOT so that dotnet-tools work (re-evaluated on cd via precmd, after mise)
      function _update_dotnet_root() {
        export DOTNET_ROOT=$(mise where dotnet-core 2>/dev/null)
      }
      add-zsh-hook precmd _update_dotnet_root

      export DISABLE_AUTOUPDATER=1 # turn off claude code's broken updater
    '';
    envExtra = ''
      export PATH=$HOME/bin:$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:$HOME/.dotnet/tools:$PATH
    '';
    profileExtra = ''
      # If this shell is reached via SSH/Mosh, use a separate agent (no desktop GUI prompts)
      if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ] || [ -n "$MOSH_CONNECTION" ]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent-remote.sock"

        # run a new ssh-agent in the background if socket not already available
        if [ ! -S "$SSH_AUTH_SOCK" ]; then
          eval "$(ssh-agent -a "$SSH_AUTH_SOCK" -s)" >/dev/null
        fi
      fi
    '';
    shellAliases = {
      # file operations
      ll = "ls -lh --color";
      la = "ls -alh --color";
      md = "mkdir -p";
      rd = "rmdir";
      "cd.." = "cd ..";
      ".." = "cd ..";
      trash = "gio trash";
      xx = "chmod +x";
      agh = "ag --hidden";
      absolute = "readlink -f";

      # rust
      c = "cargo";
      cb = "cargo build";
      cbr = "cargo build --release";
      cf = "cargo fmt && git diff";
      cr = "cargo run";
      ct = "cargo test";

      # dotnet
      d = "dotnet";
      db = "dotnet build";
      dnf = "dotnet format && git diff";
      dr = "dotnet run";
      dt = "dotnet test";
      ds = "dotnet user-secrets";

      # git tools
      gk = "gitk &";
      gka = "gitk --all &";

      # git
      g = "git";
      gf = "git fa";
      gl = "git fa && git rebase";
      gm = "git merge";
      gmm = "git merge --no-ff";
      ga = "git add -A";
      gas = "ga && gdc";
      gam = "git commit --amend";
      gap = "git add -p";
      gco = "git checkout";
      gb = "git checkout -b";
      gs = "git st";
      gsh = "git show --patch --stat=200 --show-signature";
      gshf = "git show --patch --stat=200 --show-signature --first-parent";
      gss = "git show --stat=200";
      gshq = "git show --patch --stat=200 -- ':!*package-lock.json' ':!*.lock' ':!*.feature.cs' ':!*.lock.json'";
      gt = "git tag";
      gtl = "git tag | sort --version-sort";
      gd = "git diff --patch --stat=200";
      gdw = "gd --ignore-all-space";
      gds = "git diff --stat=200";
      gdc = "git diff --patch --stat=200 --cached";
      gdwc = "gdc --ignore-all-space";
      gdsc = "git diff --stat=200 --cached";
      gdcq = "git diff --patch --stat=200 --cached -- ':!*package-lock.json' ':!*.lock' ':!*.feature.cs' ':!*.lock.json'";
      gc = "git commit -v";
      gca = "git commit -av";
      gcam = "git commit -av -m";
      gcm = "git commit -v -m";
      gcp = "git commit -pv";
      gg = "tig --stat=200,180";
      ggu = "tig @{u} --stat=200,180";
      ggf = "tig --first-parent -m --stat=200,180";
      ggm = "git ggm";
      gG = "tig --all --stat=200,180";
      GG = "tig --all --stat=200,180";
      gra = "git ra";
      graa = "git ra -a";
      gri = "git ri";
      gr = "git rebase";
      gp = "git push";
      gpt = "echo 'Preview (gptt to push):' && git push --tags -n";
      gptt = "git push --tags";
      gpu = "git pushu";
      gpf = "git push --force-with-lease";
      tb = "tig blame";
      ui = "gitui";

      # hub/github
      pr = "hub pull-request";
      prc = "gh pr checkout";
      ghw = "gh repo view --web";
      gw = "ghw";

      # kubernetes
      kc = "kubectl";
    };
  };

  # --- git ---

  programs.git = {
    enable = true;
    includes = [
      { path = "~/.gitconfig.local"; }
    ];
    aliases = {
      b = "branch";
      bd = "branch -D";
      br = "brs";
      bra = "branch --all";
      brd = "branch -D";
      brdd = "!f(){ git branch -D \${1}; git push origin --delete \${1}; };f";
      brm = "branch --all --merged";
      brr = "branch --remote";
      brs = "for-each-ref --format='%(refname:short) %(upstream:track) %(upstream:remotename)' refs/heads";
      brw = "for-each-ref --format='%1B[0;31m%(refname:short)%1B[m | %(authorname) | %(committerdate)' --sort=committerdate refs/remotes";
      co = "checkout";
      cp = "cherry-pick";
      doff = "reset HEAD^";
      fa = "fetch --all --prune";
      fp = "log --first-parent --format=format:'%C(auto)%h %C(blue)%s%C(reset)| %an  %C(auto)%d %cd'";
      fp-raw = "log --first-parent --format=format:'%h %s| %an %d %cd'";
      ll = "log --format=format:'%C(auto)%h %cd %C(blue)\\\"%s\\\"%C(reset) 📝 %an %C(auto)%d' --date='format:%Y-%m-%d %H:%M'";
      llf = "ll --first-parent";
      local-branches = "branch --format='%(refname:short)'";
      mt = "mergetool";
      pushf = "push --force-with-lease";
      pushu = "!git push --set-upstream $(git config remote.pushDefault || echo origin) $(git symbolic-ref --short HEAD)";
      ra = "commit --amend --reset-author -CHEAD";
      rba = "rebase --abort";
      rbc = "rebase --continue";
      rbo = "rebase --onto";
      rh = "reset --hard";
      ri = "rebase --interactive";
      rr = "reset";
      rrw = "checkout -- .";
      sa = "stash apply";
      sd = "stash drop";
      sl = "stash list";
      sp = "stash pop";
      ss = "stash save";
      ssh = "stash show -p";
      sss = "!git stash save \"savesnapshot: $(date)\" && git stash apply 'stash@{0}'";
      st = "status --short --branch";
      tr = "log --graph --oneline --decorate --color --pretty=format:'%C(auto)%h %d %s %C(green)[%G?]%Creset'";
      tree = "log --graph --oneline --decorate --color --all --pretty=format:'%C(auto)%h %d %s %C(green)[%G?]%Creset'";
      treef = "log --graph --oneline --decorate --color --first-parent --pretty=format:'%C(auto)%h %d %s %C(green)[%G?]%Creset'";
      trf = "treef";
      trm = "!f() { merge_commit=$1; feature_branch=$(git log -m --pretty=format:\"%H %P\" $merge_commit -1 | cut -f 3 -d \" \"); git log --graph --oneline --decorate --color --first-parent $(git rev-list $feature_branch ^$merge_commit^) $(git rev-list $merge_commit --first-parent); }; f";
      ggm = "!f() { merge_commit=$1; feature_branch=$(git log -m --pretty=format:\"%H %P\" $merge_commit -1 | cut -f 3 -d \" \"); tig --first-parent $(git rev-list $feature_branch ^$merge_commit^) $(git rev-list $merge_commit --first-parent); }; f";
    };
    extraConfig = {
      branch.autosetuprebase = "always";
      color.ui = "auto";
      core = {
        excludesfile = "~/.gitignore";
        editor = "vim";
        whitespace = "warn";
        pager = "delta";
      };
      interactive = {
        singlekey = true;
        diffFilter = "delta --color-only";
      };
      merge = {
        summary = true;
        tool = "kdiff3";
      };
      push.default = "upstream";
      rebase = {
        autosquash = true;
        autoStash = true;
      };
      diff = {
        algorithm = "patience";
        guitool = "kdiff3";
      };
      web.browser = "chromium-browser";
      delta = {
        line-numbers = true;
        syntax-theme = "Solarized (light)";
      };
      commit.gpgsign = true;
      init.defaultBranch = "main";
    };
  };

  # --- vim ---

  home.file.".vimrc".source = ../dotfiles/vim/vimrc;
  home.file.".gvimrc".source = ../dotfiles/vim/gvimrc;
  home.file.".vimbundle".source = ../dotfiles/vim/vimbundle;

  # --- tig ---

  home.file.".tigrc".text = ''
    bind generic w :toggle wrap-lines
    set log-options = --show-signature
    set diff-options = --show-signature
    set main-view = id, date, author, commit-title:graph=v2,refs=true
    set line-graphics = utf-8
    set main-view-date-display = relative-compact
    set main-view-author-width = 18
  '';

  # --- ideavimrc ---

  home.file.".ideavimrc".text = ''
    set ignorecase smartcase
  '';

  # --- psql ---

  home.file.".psqlrc".text = ''
    \pset linestyle unicode
    \pset border 2
    \pset null ¤
    \set PROMPT1 '%[%033[33;1m%]%x%[%033[0m%]%[%033[1m%]%/%[%033[0m%]%R%# '
    \pset pager off
    \timing
    \pset format wrapped
    \x auto

    \set show_slow_queries 'SELECT (total_time / 1000 / 60) as total_minutes, (total_time/calls) as average_time, query FROM pg_stat_statements ORDER BY 1 DESC LIMIT 100;'
    \set show_row_counts 'SELECT schemaname, relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;'
    \set show_all_row_counts 'SELECT sum(n_live_tup) FROM pg_stat_user_tables;'
  '';

  # --- git global ignore (renamed from .cvsignore) ---

  home.file.".gitignore".text = ''
    *~
    .*.sw?
    .sw?
    .DS_Store
    /tags
    *.orig
    *.local
    .idea
    *.user
    .jekyll-cache
    .claude
    *.syncthing.*.tmp
  '';

  # --- zsh functions (sourced via initExtra) ---

  home.file.".zsh/functions/gx".source = ../dotfiles/zsh/functions/gx;
  home.file.".zsh/functions/ff".source = ../dotfiles/zsh/functions/ff;
  home.file.".zsh/functions/ffe".source = ../dotfiles/zsh/functions/ffe;
  home.file.".zsh/functions/gdq".source = ../dotfiles/zsh/functions/gdq;
  home.file.".zsh/functions/gglocal".source = ../dotfiles/zsh/functions/gglocal;
  home.file.".zsh/functions/git-brmv".source = ../dotfiles/zsh/functions/git-brmv;

  # --- XDG config files ---

  xdg.configFile = {
    # ghostty
    "ghostty/config".source = ../dotfiles/ghostty-config;

    # zellij
    "zellij/config.kdl".source = ../dotfiles/zellij/config.kdl;

    # gitui solarized theme
    "gitui/theme.ron".source = ../dotfiles/gitui-theme.ron;

    # mise (tool version manager)
    "mise/config.toml".source = ../dotfiles/mise-config.toml;

    # pipewire: block slack from controlling mic volume
    "pipewire/pipewire-pulse.conf.d/20-slack-block-mic.conf".source =
      ../dotfiles/pipewire-slack-block-mic.conf;

    # redshift profiles (switch manually as needed)
    "redshift-day.conf".source = ../dotfiles/redshift-day.conf;
    "redshift-night.conf".source = ../dotfiles/redshift-night.conf;

    # logseq
    "logseq/config/plugins.edn".source = ../dotfiles/logseq/config/plugins.edn;
    "logseq/settings/logseq-task-management-shortcuts.json".source =
      ../dotfiles/logseq/settings/logseq-task-management-shortcuts.json;
  };

  # --- cargo ---

  home.file.".cargo/config.toml".source = ../dotfiles/cargo-config.toml;

  # --- redshift (user service uses day profile by default) ---

  services.redshift = {
    enable = true;
    latitude = 51.0;
    longitude = -1.0;
    temperature = {
      day = 6500;
      night = 3500;
    };
    settings.redshift = {
      brightness-day = "1";
      brightness-night = "0.8";
    };
  };

  # --- packages available to this user ---

  home.packages = with pkgs; [
    hub
  ];
}
