# Tmux fancy git status

Prints git information for the current pane (if $cwd is a git repo)

![img](https://github.com/jrudess/tmux-fancy-git/blob/master/screenshot.png)

## Dependencies

[diffstat](https://invisible-island.net/diffstat)

## Installation
### [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) (recommended)

Add plugin to the list of TPM plugins in `.tmux.conf`:

    set -g @plugin 'jrudess/tmux-fancy-git'

Add `#{fancy_git}` to your `status-left` or `status-right` tmux option:
```
set -g status-left "#{fancy_git}"
```

Press `prefix + I` to fetch the plugin and source it.

