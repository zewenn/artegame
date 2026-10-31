FROM alpine:edge AS aarch64_alpine_builder

RUN apk update
RUN apk add zig

WORKDIR /amrap/
COPY . /amrap/

WORKDIR /amrap/zig-out
WORKDIR /amrap/zig-out/final
WORKDIR /amrap/

RUN zig build -Dtarget=aarch64-macos --release=safe \
    && mv ./zig-out/bin/amrap ./zig-out/final/aarch64_macos_amrap

RUN zig build -Dtarget=x86_64-windows --release=safe \
    && mv ./zig-out/bin/amrap.exe ./zig-out/final/x86_64_windows_amrap.exe


FROM --platform=linux/amd64 ubuntu:22.04  AS x86_64_ubuntu_builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl pkgconf ca-certificates \
    libx11-dev libxcursor-dev libxext-dev libxfixes-dev \
    libxi-dev libxinerama-dev libxrandr-dev libxrender-dev \
    libgl1-mesa-dev libc6-dev-amd64-cross

WORKDIR /opt/zig
WORKDIR /

RUN curl -L https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz \
    | tar -xJ -C /opt/zig --strip-components=1 \
    && ln -s /opt/zig/zig /usr/local/bin/zig

WORKDIR /amrap
COPY . /amrap

WORKDIR /amrap/zig-out
WORKDIR /amrap/zig-out/final
WORKDIR /amrap/

RUN rm -rf .zig-cache/
RUN ["zig", "build", "-Dtarget=x86_64-linux-gnu", "--release=safe", "--seed", "0"]
RUN mv ./zig-out/bin/amrap ./zig-out/final/x86_64_linux_amrap


FROM scratch AS export


COPY --from=aarch64_alpine_builder /amrap/src/assets /assets/
COPY --from=aarch64_alpine_builder /amrap/zig-out/final /
COPY --from=x86_64_ubuntu_builder /amrap/zig-out/final /