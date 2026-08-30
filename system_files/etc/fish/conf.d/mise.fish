if not test -x $HOME/.local/bin/mise
    curl https://mise.run | sh
end

if test -x $HOME/.local/bin/mise
    $HOME/.local/bin/mise activate fish | source
end
