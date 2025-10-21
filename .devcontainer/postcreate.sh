#!/bin/bash

echo "Creation script running..."

apt-get update

# Add GitHub to known_hosts so first Git call is non-interactive:
mkdir -p ~/.ssh
ssh-keyscan -t rsa,ecdsa,ed25519 github.com >> ~/.ssh/known_hosts

# Install Perl dependencies
apt-get install -y --no-install-recommends libdbd-pg-perl libpq-dev
apt-get install -y perl
curl -L https://cpanmin.us | perl - --sudo App::cpanminus

# Install cpan deps from cpanfile (if it exists)
if [ -f "Makefile.PL" ]; then
    cpanm --installdeps --notest .
fi

# Install frontend dependencies and build
echo "Installing frontend dependencies..."
if [ -d "frontend" ]; then
    cd frontend
    npm install
    npm run build
    cd ..
    echo "✓ Frontend dependencies installed and built"
fi

# Install Claude CLI as vscode user to avoid permission issues
echo "Installing Claude CLI..."

# First, ensure the vscode user exists and has a home directory
if ! id -u vscode >/dev/null 2>&1; then
    echo "⚠ vscode user not found, creating..."
    useradd -m -s /bin/bash vscode
fi

# Set up npm and Claude CLI for vscode user with proper environment
sudo -u vscode -i bash << 'EOF'
# Set up environment
export HOME=/home/vscode
cd $HOME

# Configure npm to use a local directory for global packages
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'

# Add npm global bin to PATH in .bashrc if not already there
if ! grep -q "npm-global" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# NPM Global packages" >> ~/.bashrc
    echo "export PATH=~/.npm-global/bin:\$PATH" >> ~/.bashrc
fi

# Set PATH for current session
export PATH="~/.npm-global/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# Install Claude CLI
echo "Installing Claude CLI to ~/.npm-global..."
npm install -g @anthropic-ai/claude-code

# Create Claude configuration directory
mkdir -p ~/.config/claude

# Test Claude CLI installation
echo "Testing Claude CLI installation..."
if [ -f "$HOME/.npm-global/bin/claude" ]; then
    echo "✓ Claude CLI binary found at ~/.npm-global/bin/claude"
    $HOME/.npm-global/bin/claude --version
else
    echo "⚠ Claude CLI binary not found in expected location"
    echo "Checking npm global bin directory:"
    ls -la ~/.npm-global/bin/ || echo "Directory doesn't exist"
fi
EOF

echo "✓ Creation script completed!"
