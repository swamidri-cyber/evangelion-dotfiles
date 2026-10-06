source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# OpenClaw Completion
test -f '/home/swami/.openclaw/completions/openclaw.fish'; and source '/home/swami/.openclaw/completions/openclaw.fish'
