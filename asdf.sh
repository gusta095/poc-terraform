#!/bin/bash

echo "Preparetion ASDF"

check_deps() {
    local error_messages=()

    [[ ! "$(command -v git)" ]] && error_messages+=("terragrunt could not be found")
    [[ ! "$(command -v curl)" ]] && error_messages+=("curl could not be found")
    [[ ! "$(command -v unzip)" ]] && error_messages+=("unzip could not be found")

    if [[ -n "${error_messages[*]}" ]]; then
        for msg in "${error_messages[@]}"; do
            echo "${msg}"
            exit 1
        done
    fi
}

install() {
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf 

    echo " " >> ~/.bashrc
    echo '. $HOME/.asdf/asdf.sh' >> ~/.bashrc
    echo '. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
    source ~/.bashrc

    echo '. $HOME/.asdf/asdf.sh' >> ~/.zshrc
    echo '. $HOME/.asdf/completions/asdf.bash' >> ~/.zshrc
    source ~/.zshrc
}

install_plugins() {
    echo "add plugins"
    asdf plugin add terraform
    asdf plugin add terragrunt
    asdf plugin add terraform-docs
    asdf plugin add shellcheck
    asdf plugin add vault

    echo "plugins list"
    asdf plugin list
}

main() {
    check_deps
    install
    install_plugins

    echo "Execution done!"
}

main "$@"