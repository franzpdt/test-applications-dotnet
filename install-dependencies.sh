#!/usr/bin/env bash
set -euo pipefail

DOTNET_VERSION="10.0"

echo "=== Installing dependencies for test-applications-dotnet ==="

# Detect OS
OS="$(uname -s)"

install_dotnet_linux() {
    # Try to detect distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
    else
        DISTRO="unknown"
    fi

    case "$DISTRO" in
        ubuntu|debian)
            install_dotnet_via_script
            ;;
        fedora|rhel|centos)
            sudo dnf install -y "dotnet-sdk-${DOTNET_VERSION}"
            ;;
        *)
            echo "Unsupported Linux distro: $DISTRO. Installing via dotnet-install script..."
            install_dotnet_via_script
            ;;
    esac
}

install_dotnet_via_script() {
    echo "Installing .NET SDK ${DOTNET_VERSION} via dotnet-install script..."
    tmpdir="$(mktemp -d)"
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o "${tmpdir}/dotnet-install.sh"
    chmod +x "${tmpdir}/dotnet-install.sh"
    "${tmpdir}/dotnet-install.sh" --channel "${DOTNET_VERSION}"
    rm -rf "${tmpdir}"

    # Add to PATH for current session
    export DOTNET_ROOT="${HOME}/.dotnet"
    export PATH="${DOTNET_ROOT}:${PATH}"

    echo ""
    echo "Add the following to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo "  export DOTNET_ROOT=\"\${HOME}/.dotnet\""
    echo "  export PATH=\"\${DOTNET_ROOT}:\${PATH}\""
}

case "$OS" in
    Darwin)
        if command -v brew &>/dev/null; then
            echo "Installing .NET SDK ${DOTNET_VERSION} via Homebrew..."
            brew install --cask dotnet-sdk
        else
            echo "Homebrew not found. Installing .NET SDK via dotnet-install script..."
            install_dotnet_via_script
        fi
        ;;
    Linux)
        install_dotnet_linux
        ;;
    *)
        echo "Unsupported OS: $OS. Attempting dotnet-install script..."
        install_dotnet_via_script
        ;;
esac

echo ""
echo "=== Verifying installation ==="
if command -v dotnet &>/dev/null; then
    echo "dotnet SDK installed: $(dotnet --version)"
else
    echo "WARNING: 'dotnet' not found on PATH. You may need to restart your shell or update your PATH."
    exit 1
fi

echo ""
echo "=== Restoring NuGet packages ==="
dotnet restore "$(dirname "$0")/TaskApi/TaskApi.csproj"

echo ""
echo "=== All dependencies installed successfully ==="
