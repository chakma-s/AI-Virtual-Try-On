FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Set up Flutter as the default 'vscode' user
USER vscode
WORKDIR /home/vscode

# Install Flutter stable branch
RUN git clone https://github.com/flutter/flutter.git -b stable flutter
ENV PATH="/home/vscode/flutter/bin:${PATH}"

# Pre-cache flutter dependencies and enable web
RUN flutter config --no-analytics && \
    flutter config --enable-web && \
    flutter precache --web
